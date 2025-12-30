CREATE OR REPLACE PROCEDURE crash_daily_refresh
IS
    /**********************************************************************
    This procedure loads the ACCIDENT tables from CRASH that do not require a location from metrans daily.
    
    These include ACCIDENT_PEOPLE, ACCIDENT_UNITS, ACCIDENT_COMMERCIAL_CARRIER, ACCIDENT_NONVEHICLE_PROPDAMAGE

    The ACCIDENTS table is only loaded on the weekend
    09-19-2019 SH - Initial Version, copied from CRASH_WEEKLY_REFRESH
    12-26-2019 SH - Gather optimizer stats before loading crash_cost to resolve performance issue
    04-27-2023 SH - Gather optimizer stats after loading for large tables:  ACCIDENTS, CRASHES_ON_ROUTE
    **********************************************************************/

    g_owner                     VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                   VARCHAR2 (30) := 'CRASH_DAILY_REFRESH';
    g_object                    VARCHAR2 (20) := 'ACCIDENTS';
    g_sqlmsg                    VARCHAR2 (500) := NULL;
    g_start_time                DATE := SYSDATE;

    accidents_errlog_count      NUMBER;
    people_errlog_count         NUMBER;
    units_errlog_count          NUMBER;
    cc_errlog_count             NUMBER;
    damaged_prop_errlog_count   NUMBER;
    cor_errlog_count            NUMBER;
    err_log_message             VARCHAR2 (200) := NULL;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ACCIDENTS_ERROR_LOG';  -- accidents updated with crash_cost, pedestrian/bike crashes
    DBMS_MVIEW.refresh ('MV_CRASH_INJURYCOUNT', 'C', atomic_refresh => FALSE);
    DBMS_MVIEW.refresh ('MV_CRASH_LOOKUPS', 'C', atomic_refresh => FALSE);


    load_accident_people;
    load_accident_units;
    DBMS_STATS.gather_table_stats ('WH_ASSETS', 'ACCIDENT_UNITS');
    DBMS_STATS.gather_table_stats ('WH_ASSETS', 'ACCIDENT_PEOPLE');
    load_pedbike_crashes;
    load_crash_cost;
    load_accident_comm_carrier;
    load_accident_damaged_property;


    DBMS_MVIEW.refresh ('MV_CRASH_PEOPLE_UNITS', 'C', atomic_refresh => FALSE);
    DBMS_MVIEW.refresh ('MV_BNS_PED_BIKE', 'C', atomic_refresh => FALSE);
    load_crashes_on_route;
    DBMS_STATS.gather_table_stats ('WH_ASSETS', 'ACCIDENTS');
    DBMS_STATS.gather_table_stats ('WH_ASSETS', 'CRASHES_ON_ROUTE');

    SELECT COUNT (*) INTO accidents_errlog_count FROM accidents_error_log;

    SELECT COUNT (*) INTO people_errlog_count FROM accident_people_error_log;

    SELECT COUNT (*) INTO units_errlog_count FROM accident_units_error_log;

    SELECT COUNT (*) INTO cc_errlog_count FROM accident_cc_error_log;


    SELECT COUNT (*)
      INTO damaged_prop_errlog_count
      FROM accident_nvpd_error_log;

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
                         'CRASH_DAILY_REFERSH',
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
                         'CRASH_DAILY_REFERSH',
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
                'Unexpected Data Quality Issues in accidents error log updating crash cost';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'CRASH_DAILY_REFERSH',
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
                         'CRASH_DAILY_REFERSH',
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
                         'CRASH_DAILY_REFERSH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('ACCIDENT_NVPD_ERROR_LOG',
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
                         'CRASH_DAILY_REFERSH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('CRASHES_ON_ROUTE_ERROR_LOG',
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
