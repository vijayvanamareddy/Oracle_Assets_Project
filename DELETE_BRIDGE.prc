CREATE OR REPLACE PROCEDURE DELETE_BRIDGE (
    BRIDGE_NUM   IN IBRIDGES_HISTORY.BRIDGE_NUMBER%TYPE)
AS
  /**********************************************************************
    This procedure deletes an individual bridge from ibridges_history, rail_bridges_history,
    and IBRDG_ROADS_ASSOC_HISTORY and logs the changes in ibridges_changes
    
    It is intended to clean-up data entry type errors on the source system for example bridge '0106R'
    
    2-26-2019 SH  Initial Version
  ***********************************************************************/
    cnt          NUMBER;
    g_start_time   DATE := SYSDATE;
    ierrlog      NUMBER;
    rrerrlog     NUMBER;
    rerrlog      NUMBER;
    err_log_message          VARCHAR2 (200) := NULL;
    g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
    g_object                 VARCHAR2 (20) := 'IBRIDGES_HISTORY';
    V_flat_file_counts_txt   VARCHAR2 (1000) := NULL;
BEGIN
    SELECT COUNT (*)
      INTO cnt
      FROM IBRIDGES_HISTORY
     WHERE BRIDGE_NUMBER = trim(BRIDGE_NUM);

    IF cnt >= 1
    THEN
        DELETE FROM IBRIDGES_HISTORY
              WHERE BRIDGE_NUMBER = trim(BRIDGE_NUM)
                LOG ERRORS INTO ibridges_history_error_log
                        ('delete bridge' || SYSDATE)
                        REJECT LIMIT 100;

        INSERT INTO ibridges_changes                            -- log deletes
                                     (table_name,
                                      bridge_number,
                                      change_type,
                                      change_date,
                                      column_name,
                                      modified_by,
                                      old_value,
                                      new_value)
             VALUES ('IBRIDGES_HISTORY',
                     bridge_num,
                     'D',
                     g_start_time,
                     NULL,
                     'DELETE_BRIDGE',
                     NULL,
                     NULL);
    END IF;

    SELECT COUNT (*)
      INTO cnt
      FROM RAIL_BRIDGES_HISTORY
     WHERE BRIDGE_NUMBER = trim(BRIDGE_NUM);

    IF cnt >= 1
    THEN
        DELETE FROM RAIL_BRIDGES_HISTORY
              WHERE BRIDGE_NUMBER = trim(BRIDGE_NUM)
                LOG ERRORS INTO RAIL_BRIDGES_ERROR_LOG
                        ('delete bridge' || SYSDATE)
                        REJECT LIMIT 100;

        INSERT INTO ibridges_changes                            -- log deletes
                                     (table_name,
                                      bridge_number,
                                      change_type,
                                      change_date,
                                      column_name,
                                      modified_by,
                                      old_value,
                                      new_value)
             VALUES ('RAIL_BRIDGES_HISTORY',
                     bridge_num,
                     'D',
                     g_start_time,
                     NULL,
                     'DELETE_BRIDGE',
                     NULL,
                     NULL);
    END IF;

    SELECT COUNT (*)
      INTO cnt
      FROM IBRDG_ROADS_ASSOC_HISTORY
     WHERE BRIDGE_NUMBER = trim(BRIDGE_NUM);

    IF cnt >= 1
    THEN
        DELETE FROM IBRDG_ROADS_ASSOC_HISTORY
              WHERE BRIDGE_NUMBER = trim(BRIDGE_NUM)
                LOG ERRORS INTO IBRIDGE_ROADS_ASSOC_ERROR_LOG
                        ('delete bridge' || SYSDATE)
                        REJECT LIMIT 100;

        INSERT INTO ibridges_changes                            -- log deletes
                                     (table_name,
                                      bridge_number,
                                      change_type,
                                      change_date,
                                      column_name,
                                      modified_by,
                                      old_value,
                                      new_value)
             VALUES ('IBRDG_ROADS_ASSOC_HISTORY',
                     bridge_num,
                     'D',
                     g_start_time,
                     NULL,
                     'DELETE_BRIDGE',
                     NULL,
                     NULL);
    END IF;

    COMMIT;

  
    SELECT COUNT (*) INTO ierrlog FROM ibridges_history_error_log;

    SELECT COUNT (*) INTO rrerrlog FROM RAIL_BRIDGES_ERROR_LOG;

    SELECT COUNT (*) INTO rerrlog FROM IBRIDGE_ROADS_ASSOC_ERROR_LOG;

    IF ierrlog > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in ibridges_history_error_log';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'DELETE_BRIDGE',
                         'WH_ASSETS',
                         err_log_message);
           
           SELECT COUNT (*) INTO cnt FROM ibridges_HISTORY;

            WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
                OWNER         => 'WH_ASSETS',
                OBJECT_NAME   => 'IBRIDGES_HISTORY',
                object_cnt    => cnt,
                proc          => $$PLSQL_UNIT,
                start_time    => g_start_time);

            COMMIT;
        END;
    END IF;

    IF rrerrlog > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in RAIL_BRIDGES_ERROR_LOG';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'DELETE_BRIDGE',
                         'WH_ASSETS',
                         err_log_message);
          SELECT COUNT (*) INTO cnt FROM RAIL_BRIDGES_HISTORY;


            WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
                OWNER         => 'WH_ASSETS',
                OBJECT_NAME   => 'RAIL_BRIDGES_HISTORY',
                object_cnt    => cnt,
                proc          => $$PLSQL_UNIT,
                start_time    => g_start_time);

            COMMIT;
        END;
    END IF;

    IF rerrlog > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in IBRIDGE_ROADS_ASSOC_ERROR_LOG';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'DELETE_BRIDGE',
                         'WH_ASSETS',
                         err_log_message);
           SELECT COUNT (*) INTO cnt FROM IBRDG_ROADS_ASSOC_HISTORY;

            WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
                OWNER         => 'WH_ASSETS',
                OBJECT_NAME   => 'IBRDG_ROADS_ASSOC_HISTORY',
                object_cnt    => cnt,
                proc          => $$PLSQL_UNIT,
                start_time    => g_start_time);

            COMMIT;
        END;
    END IF;
    
    select count(*) into cnt from ibridges_history;
   WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (OWNER => G_OWNER, OBJECT_NAME => g_object,
       object_cnt => cnt,
       proc => $$PLSQL_UNIT, start_time => g_start_time);
EXCEPTION
    WHEN OTHERS
    THEN
        wh_common.pkg_common_utilities.update_whse_log (
            'WH_ASSETS',
            $$PLSQL_UNIT,
            NULL,
            NULL,
            NULL,
            NULL,
               'Error during '
            || $$PLSQL_UNIT
            || ' Line:'
            || $$PLSQL_LINE
            || ': '
            || SUBSTR (SQLERRM, 1, 400),
            'Failed');
        wh_common.pkg_common_utilities.exit_and_report (
            $$PLSQL_UNIT,
            'FAILURE',
               'Error during '
            || $$PLSQL_UNIT
            || ': '
            || SUBSTR (SQLERRM, 1, 400));
        RAISE_APPLICATION_ERROR (
            -20050,
            $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
END;
/
