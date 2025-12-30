CREATE OR REPLACE PROCEDURE crash_weekly_refresh
IS
    /**********************************************************************
    This procedure is the driving procedure that loads the accidents tables from CRASH.
    It is run weekly as part of the control assets cycle.
    It then checks the error logs

    08-22-2017 SH - Initial Version
    08-24-2017 SH - Add associated_nodes
    08-30-2017 SH - Add NODES
    09-13-2017 SH - check nodes error log
    11-21-2017 SH - Load Nodes before crashes so we can use nodes_on_route view 
    06-12-2018 SH - Add load_accident_damaged_property
    08-08-2018 SH - Replace load_nodes with load_all_nodes
    08-09-2018 SH - Replace load_all_nodes with load_nodes (after renaming all_nodes table to nodes)
    08-10-2018 SH - Refresh materialized views:  MV_HIGHWAY_NETWORK,MV_CRASHES_ON_ROUTE;
    09-18-2018 SH - Execute load_accidents2 which loads the complete network so we can compare to highway network for testing purposes
    10-05-2018 SH - Refresh new mvs:  MV_HIGHWAY_NETWORK2,MV_CRASHES_ON_ROUTE2 in preparation for moving to complete network
    10-08-2018 SH - Add load_creash_cost2 to update accidents2
    10-11-2018 SH - MV_CRASHES_ON_ROUTE now uses complete network, commenting out old mv refresh
    11-27-2018 SH - Dropped old mvs of highway network to cleanup, changing refresh to new mvs
                    Remove references to accidents2
    12-21-2018 SH - Add refresh of MV_CRASH_PEOPLE_UNITS      
    01-08-2019 SH - Refresh  mvs:  mv_crash_injury_count, mv_crash_lookups   
    01-21-2019 SH - Moved to production     
    01-28-2019 SH - Refresh MV_BNS_PED_BIKE  
    02-22-2019 SH - Run load_high_crash_locations to update the location of the highway network
    03-06-2019 SH - Replace load_nodes procedure with node_weekly_refresh procedure as we are now keeping history so we can snapshot nodes
    03-26-2019 SH - Moved from dev to test
    04-01-2019 SH - Modify refresh procedures execution parameters.  Remove gathering optimizer stats as that is done automatically in 12C
    04-12-2019 SH - Replace mv_crashes_on_route with table crashes_on_route.  Replace refresh with load_crashes_on_route procedure. 
    04-17-2019 SH - Change mv_complete_network to a table & view complete_transportation_network, v_complete_network and mv_highway_network to a view, v_highway_network
                    Remove DBMS_MVIEW.refresh of mv_highway_network 
    05-02-2019 SH - Replace running load_high_crash_locations procedure which truncated and reloaded weekly with HIGH_CRASH_LOC_WKLY_REFRESH
                    which updates the location information of the most current year of high crash locations.  Done after adding the 2018
                    high crash locations into the high_crash_location table  
    07-11-2019 SH - Add procedure load_pedbike_crashes which updates the accident table with columns indicating if a crash involves a pedestrian or bicycle  
    08-08-2019 SH - Run node_weekly_refresh as part of control_assets_cycle so it can be run before loading the complete network 
    12-26-2019 SH - Gather optimizer stats before loading crash_cost to resolve performance issue
    **********************************************************************/
  CURSOR history_tables
    IS
        SELECT table_name
          FROM STANDARD_ASSET_CYCLE_BKPS
         WHERE table_name LIKE 'ACCIDENT%';
         
    g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                VARCHAR2 (30) := 'CRASH_WEEKLY_REFRESH';
    g_object                 VARCHAR2 (20) := 'ACCIDENTS';
    g_sqlmsg                 VARCHAR2 (500) := NULL;
    g_start_time             DATE := SYSDATE;

    accidents_errlog_count   NUMBER;
    people_errlog_count      NUMBER;
    units_errlog_count       NUMBER;
    cc_errlog_count          NUMBER;
    anodes_errlog_count      NUMBER;
    nodes_errlog_count       NUMBER;
    damaged_prop_errlog_count NUMBER;
    cor_errlog_count         NUMBER;
    err_log_message          VARCHAR2 (200) := NULL;
BEGIN

   DBMS_MVIEW.refresh('MV_CRASH_INJURYCOUNT','C',atomic_refresh => false);
   DBMS_MVIEW.refresh('MV_CRASH_LOOKUPS','C',atomic_refresh => false);
  
    load_accidents;
    load_accident_people;
    load_accident_units;
     FOR rec IN history_tables
    LOOP
        DBMS_STATS.gather_table_stats ('wh_assets', rec.table_name);
    END LOOP;
    load_pedbike_crashes;
    load_crash_cost;
    load_accident_comm_carrier;
    load_accident_damaged_property;
    load_associated_nodes;
    high_crash_loc_wkly_refresh;
 
    DBMS_MVIEW.refresh('MV_CRASH_PEOPLE_UNITS','C',atomic_refresh => false);
    DBMS_MVIEW.refresh('MV_BNS_PED_BIKE','C',atomic_refresh => false);
    load_crashes_on_route;  

    SELECT COUNT (*)
      INTO accidents_errlog_count
      FROM accidents_error_log;

    SELECT COUNT (*)
      INTO people_errlog_count
      FROM accident_people_error_log;

    SELECT COUNT (*)
      INTO units_errlog_count
      FROM accident_units_error_log;

    SELECT COUNT (*)
      INTO cc_errlog_count
      FROM accident_cc_error_log;

    SELECT COUNT (*)
      INTO anodes_errlog_count
      FROM associated_nodes_error_log;

    SELECT COUNT (*) INTO nodes_errlog_count FROM nodes_error_log;
    
    SELECT COUNT (*) INTO damaged_prop_errlog_count FROM accident_nvpd_error_log; 
    
    SELECT COUNT (*) INTO cor_errlog_count FROM crashes_on_route_error_log;

    IF people_errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in accident people error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'CRASH_WEEKLY_REFERSH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('ACCIDENT_PEOPLE_ERROR_LOG',
                         'Invalid data in error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

    IF units_errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in accident units error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'CRASH_WEEKLY_REFERSH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('ACCIDENT_UNITS_ERROR_LOG',
                         'Invalid data in error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

    IF accidents_errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in accidents error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'CRASH_WEEKLY_REFERSH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('ACCIDENTS_ERROR_LOG',
                         'Invalid data in error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;


    IF cc_errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in accident CC error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'CRASH_WEEKLY_REFERSH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('ACCIDENT_CC_ERROR_LOG',
                         'Invalid data in error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

    IF anodes_errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in ASSOCIATED_NODES error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'CRASH_WEEKLY_REFERSH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('ASSOCIATED_NODES_ERROR_LOG',
                         'Invalid data in error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;


    IF nodes_errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in NODES error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'CRASH_WEEKLY_REFERSH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('NODES_ERROR_LOG',
                         'Invalid data in error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;
    
     IF damaged_prop_errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in Accident Damaged Property error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'CRASH_WEEKLY_REFERSH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('ACCIDENT_NVPD_ERROR_LOG'  ,
                         'Invalid data in error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;
    
      IF cor_errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in Crashes_on_route error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'CRASH_WEEKLY_REFERSH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('CRASHES_ON_ROUTE_ERROR_LOG'  ,
                         'Invalid data in error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;
    
EXCEPTION
    WHEN OTHERS
    THEN
        G_SQLMSG := $$PLSQL_UNIT || ': ' || SUBSTR (SQLERRM, 1, 400);
        WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
            OWNER         => G_OWNER,
            OBJECT_NAME   => g_object,
            MSG           => G_SQLMSG,
            STATUS        => 'Failed');

        WH_COMMON.PKG_COMMON_UTILITIES.EXIT_AND_REPORT (
            g_jobname,
            'FAILURE',
            $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
        RAISE_APPLICATION_ERROR (-20010, $$PLSQL_UNIT || ' ' || G_SQLMSG);
END;
/
