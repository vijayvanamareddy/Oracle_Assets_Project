CREATE OR REPLACE PROCEDURE delete_retired_bridges
IS
    /**********************************************************************
    This procedure will remove retired rows (state = RETIRED) from ibridges_history
    making it easier to query.  These rows were generally (but not always) caused by a failure
    in the etl process.

    When a retired row is deleted , the time stamps (start-end date) indicating the period of time the historical version of the bridge covers is adjusted.
    The start_date of a snapshot year should = the end_date of the prior year.

    Archived bridges (asset_status = 0) always have a state of RETIRED.  When a new snapshot is created,  archived bridges are not included.
    Archived bridges with a state of RETIRED are not deleted by this procedure.  The version of the row that remains is the one with
    the highest bridge_id, which is also in the view archived_bridges.

    This procedure can be run periodically.

    06-28-22 S Hillson Initial Version
    **********************************************************************/

    --  in-service bridges

    -- Retired rows for in-service bridges that will be deleted
    CURSOR ibrdg IS
          SELECT bridge_number, bridge_id, state
            FROM ibridges_history
           WHERE     bridge_number NOT IN
                         (SELECT bridge_number FROM archived_bridges)
                 AND state = 'RETIRED'
        ORDER BY BRIDGE_NUMBER;

    --  Adjust start-end dates for in-service bridges after removing retired rows
    CURSOR inbrdg IS
          SELECT snapshot_year,
                 bridge_number,
                 start_date,
                 end_date,
                 state,
                 bridge_id,
                 LAG (end_date) OVER (ORDER BY bridge_number, snapshot_year)
                     AS prev_end_date,
                 LAG (bridge_number)
                     OVER (ORDER BY bridge_number, snapshot_year)
                     AS prev_bridge_number
            FROM ibridges_history
           WHERE bridge_number NOT IN
                     (SELECT bridge_number FROM archived_bridges)
        ORDER BY bridge_number, snapshot_year, start_date;

    -- Archived bridges
    -- Delete old RETIRED rows, keep last RETIRED row as archived bridges should be RETIRED

    CURSOR dbrdg IS
        SELECT bridge_number, bridge_ID
          FROM ibridges_history
         WHERE     bridge_number IN
                       (SELECT bridge_number FROM archived_bridges)
               AND state = 'RETIRED'
               AND bridge_id NOT IN (SELECT bridge_id FROM archived_bridges);

    --  Adjust start-end dates for archived bridges after removing retired rows
    CURSOR abrdg IS
          SELECT snapshot_year,
                 bridge_number,
                 start_date,
                 end_date,
                 state,
                 bridge_id,
                 asset_status,
                 LAG (end_date) OVER (ORDER BY bridge_number, snapshot_year)
                     AS prev_end_date,
                 LAG (bridge_number)
                     OVER (ORDER BY bridge_number, snapshot_year)
                     AS prev_bridge_number
            FROM ibridges_history
           WHERE bridge_number IN (SELECT bridge_number FROM archived_bridges)
        ORDER BY bridge_number, snapshot_year, start_date;



    cnt                      NUMBER;

    commit_count             NUMBER := 0;
    cntr                     NUMBER := 0;
    cntr_updated             NUMBER := 0;
    cntr_deleted             NUMBER := 0;
    errlog_count             NUMBER := 0;
    V_flat_file_counts_txt   VARCHAR2 (1000) := NULL;
    err_log_message          VARCHAR2 (200) := NULL;

    g_start_time             DATE := SYSDATE;
    g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                VARCHAR2 (30) := 'DELETE_RETIRED_BRIDGES';
    g_object                 VARCHAR2 (20) := 'IBRIDGES_HISTORY';
    g_sqlmsg                 VARCHAR2 (500) := NULL;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE IBRIDGES_HISTORY_ERROR_LOG';

    FOR ind IN ibrdg             -- Delete retired rows for in-service bridges
    LOOP
        DELETE FROM
            ibridges_history
              WHERE bridge_id = ind.bridge_id AND state = 'RETIRED'
                LOG ERRORS INTO ibridges_history_error_log
                        (   'Delete Retired Bridges Bridge ID  : '
                         || ind.bridge_id
                         || ' '
                         || SYSDATE)
                        REJECT LIMIT 100;

        cntr_deleted := cntr_deleted + 1;
    END LOOP;

    COMMIT;


    FOR b IN inbrdg -- Adjust dates for in-service bridges after retired rows have been deleted
    LOOP
        IF     b.start_date <> b.prev_end_date
           AND b.prev_end_date IS NOT NULL
           AND b.bridge_number = b.prev_bridge_number
        THEN
            UPDATE ibridges_history
               SET start_date = b.prev_end_date,
                   modified_by = 'DELETE_RETIRED_BRIDGES',
                   date_modified = SYSDATE
             WHERE bridge_id = b.bridge_id
               LOG ERRORS INTO ibridges_history_error_log
                       (   'Delete Retired Bridges Bridge ID  : '
                        || b.bridge_id
                        || ' '
                        || SYSDATE)
                       REJECT LIMIT 100;

            cntr_updated := cntr_updated + 1;
        END IF;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;


    FOR d IN dbrdg                 -- Delete retired rows for archived bridges
    LOOP
        DELETE FROM
            ibridges_history
              WHERE bridge_id = d.bridge_id AND state = 'RETIRED'
                LOG ERRORS INTO ibridges_history_error_log
                        (   'Delete Retired Bridges Bridge ID  : '
                         || d.bridge_id
                         || ' '
                         || SYSDATE)
                        REJECT LIMIT 100;

        cntr_deleted := cntr_deleted + 1;
    END LOOP;


    COMMIT;


    FOR a IN abrdg -- adjust dates for archived bridges after deleting retired rows
    LOOP
        IF     a.start_date <> a.prev_end_date
           AND a.prev_end_date IS NOT NULL
           AND a.bridge_number = a.prev_bridge_number
        THEN
            UPDATE ibridges_history
               SET start_date = a.prev_end_date,
                   modified_by = 'DELETE_RETIRED_BRIDGES',
                   date_modified = SYSDATE
             WHERE bridge_id = a.bridge_id
               LOG ERRORS INTO ibridges_history_error_log
                       (   'Delete Retired Bridges Bridge ID  : '
                        || a.bridge_id
                        || ' '
                        || SYSDATE)
                       REJECT LIMIT 100;

            cntr_updated := cntr_updated + 1;
        END IF;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;


    COMMIT;

    SELECT COUNT (*) INTO cntr FROM iBRIDGES_HISTORY;


    V_flat_file_counts_txt :=
           'IBRIDGES_HISTORY: '
        || 'Total Rows: '
        || cntr
        || ' Updated: '
        || cntr_updated
        || ' Deleted:  '
        || cntr_deleted;

    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
        OWNER         => 'WH_ASSETS',
        OBJECT_NAME   => 'IBRIDGES_HISTORY',
        object_cnt    => cntr,
        add_cnt       => 0,
        update_cnt    => cntr_updated,
        proc          => $$PLSQL_UNIT,
        start_time    => g_start_time);
    wh_common.pkg_common_utilities.EXIT_AND_REPORT ($$PLSQL_UNIT,
                                                    'NORMAL',
                                                    V_flat_file_counts_txt);

    -- Check error logs for quality errors
    -- Check ibridges history error log for quality errors

    SELECT COUNT (*)
      INTO errlog_count
      FROM wh_assets.ibridges_history_error_log;

    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in ibridges_history_error_log';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'DELETE_RETIRED_BRIDGES',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('IBRIDGES_HISTORY_ERROR_LOG',
                         'Invalid data - check error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;
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
