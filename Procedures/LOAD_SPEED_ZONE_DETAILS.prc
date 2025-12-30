CREATE OR REPLACE PROCEDURE load_speed_zone_details
IS
    /**********************************************************************
    This procedure loads the speed_zones detail table 

    It truncates the table and re-loads it weekly

    04-16-19 SH  Initial Version, based on view created by C. Owings
    03-31-20 SH  Change source to GIS views
      V_BNS_SPEED_ZONES_VIEW_RD_NRT – numbered routes, street name set to null

      V_BNS_SPEED_ZONES_VIEW_RD_INV – non numbered routes with street names

    09-16-20 SH Fix bug: when a speed zone does not end on a node boundary, the end milepoint was the end milepoint of the element
                Change the end milepoint to be the end milepoint where the speed zone actually ends within the element
                Since we don't want to change obiee, change column name in the table and this procedure - end_mp to end_element_mp
                Change virtual column name emp to end_mp 
                
    10-15-2020 SH Rewritten to use Dissolve Function written by Tom Marcotte and complete_transportation_network    
                  rather than GIS Source
    10-21-2020 SH Prepare to move to prod - remove references to speed_zones_d temporary table        
    **********************************************************************/


    g_start_time   DATE := SYSDATE;
    g_owner        VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname      VARCHAR2 (30) := 'LOAD_SPEED_ZONE_DETAILS';
    g_object       VARCHAR2 (20) := 'SPEED_ZONES';
    g_sqlmsg       VARCHAR2 (500) := NULL;

    errlog_count    NUMBER;
    err_log_message VARCHAR2 (200) ;
    
    last_snapshot_year NUMBER;
    cntr               NUMBER;
  

BEGIN
   
    
         EXECUTE IMMEDIATE 'TRUNCATE TABLE SPEED_ZONES';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE SPEED_ZONES_ERROR_LOG';
        
        SELECT MAX (snapshot_year) INTO last_snapshot_year FROM complete_transportation_network;

        load_speed_zones_num_rtes(last_snapshot_year);
        load_speed_zones_nonnum_rtes(last_snapshot_year);

    -- Check  error log for quality errors

    SELECT COUNT (*) INTO errlog_count FROM wh_assets.SPEED_ZONES_ERROR_LOG;

    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in SPEED_ZONES_ERROR_LOG';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'LOAD_SPEED_ZONESD',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('SPEED_ZONESD_ERROR_LOG',
                         'Invalid data - check error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

    SELECT COUNT (*) INTO cntr FROM SPEED_ZONES;

    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
        OWNER         => G_OWNER,
        OBJECT_NAME   => g_object,
        object_cnt    => cntr,
        proc          => $$PLSQL_UNIT,
        start_time    => g_start_time);
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
        RAISE_APPLICATION_ERROR (-20010, G_SQLMSG);
END;
/
