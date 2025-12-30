CREATE OR REPLACE PROCEDURE load_bridge_repairs
IS
    /**********************************************************************
    This procedure loads the bridge_repairs table with data from InspectTech

    It reads the data from the EXT_REPAIRS external tables

    It does a complete refresh daily (to start with)

    Modification History:

    05-02-2018  SH Intial Version
                   There is one row per bridge even if there are no repairs
    11-25-18 SH Change references of ibridges to ibridges_history WHERE end_date is NULL to facilitate change to new bridge selection criteria
    09-09-19 SH Change WHERE end_date is not NULL to is NULL like i said above , look up bridge_id based on year of work
    04-07-20 SH To accomodate proposed bridges, in procedure get_bridge_id check ibridges_history where end_date is NULL when getting the CURRENT
                bridge_id
    **********************************************************************/

    common_rundate         DATE := SYSDATE;
    cntr                   NUMBER;
    commit_count           NUMBER := 0;
    Last_bridge_inserted   bridge_repairs.bridge_number%TYPE;
    tbridge_id             NUMBER;

    g_start_time           DATE := SYSDATE;
    g_owner                VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname              VARCHAR2 (30) := 'LOAD_BRIDGE_REPAIRS';
    g_object               VARCHAR2 (20) := 'BRIDGE_REPAIRS';
    g_sqlmsg               VARCHAR2 (500) := NULL;

    CURSOR brdg
    IS
        SELECT r.bridge_number,
               b.bridge_name,
               r.scope,
               r.repair_done_by,
               r.year_of_repair,
               r.comments
          FROM ext_bridge_repairs  r
               JOIN ibridges_history b ON r.bridge_number = b.bridge_number
         WHERE b.end_date IS NULL
        UNION
        SELECT r2.bridge_number,
               b.bridge_name,
               r2.scope,
               r2.repair_done_by,
               r2.year_of_repair,
               r2.comments
          FROM ext_bridge_repairs2  r2
               JOIN ibridges_history b ON r2.bridge_number = b.bridge_number
         WHERE     b.end_date IS NULL
               AND NOT (    r2.year_of_repair IS NULL
                        AND r2.repair_done_by IS NULL
                        AND r2.scope IS NULL
                        AND r2.comments IS NULL)
        ORDER BY
            1,
            3,
            4,
            5,
            6 NULLS LAST;

    b                      brdg%ROWTYPE;

    FUNCTION Get_bridge_id (bridge_num VARCHAR, yr_of_repair NUMBER)
        RETURN NUMBER
    IS
        err       VARCHAR2 (100);
        cntr      NUMBER;
        brdg_id   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO cntr
          FROM ibridges_history b
         WHERE     bridge_num = b.bridge_number
               AND b.snapshot_year = yr_of_repair
               AND b.state IN ('CURRENT', 'PAST');


        IF cntr = 1
        THEN
            SELECT bridge_id
              INTO brdg_id
              FROM ibridges_history b
             WHERE     bridge_num = b.bridge_number
                   AND b.snapshot_year = yr_of_repair
                   AND b.state IN ('CURRENT', 'PAST');
        ELSE                                          -- use current bridge_id
            SELECT bridge_id
              INTO brdg_id
              FROM ibridges_history b
             WHERE b.end_date is NULL and bridge_num = b.bridge_number;
        END IF;

        RETURN brdg_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            err :=
                   'Error num :'
                || TO_CHAR (SQLCODE)
                || ' '
                || SUBSTR (SQLERRM, 1, 70);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT,
                                         COLUMN_NAME1,
                                         COLUMN_VALUE1,
                                         COLUMN_NAME2,
                                         COLUMN_VALUE2,
                                         COLUMN_NAME3,
                                         COLUMN_VALUE3)
                 VALUES ('bridge_repairs',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'PROCEDURE',
                         'Get_bridge_id',
                         'Bridge Number',
                         bridge_num,
                         'YEAR_OF_REPAIR',
                         yr_of_repair);

            RETURN NULL;
    END;



    PROCEDURE Write_it
    IS
    BEGIN
        INSERT INTO bridge_repairs (bridge_id,
                                    bridge_name,
                                    bridge_number,
                                    scope,
                                    repair_done_by,
                                    year_of_repair,
                                    comments)
                 VALUES (
                            tbridge_id,
                            b.bridge_name,
                            b.bridge_number,
                            CASE
                                WHEN ASCII (b.scope) = 0 -- convert blank to null
                                                         THEN NULL
                                ELSE b.scope
                            END,
                            CASE
                                WHEN ASCII (b.repair_done_by) = 0 -- convert blank to null
                                                                  THEN NULL
                                ELSE b.repair_done_by
                            END,
                            CASE
                                WHEN ASCII (b.year_of_repair) = 0 -- convert blank to null
                                                                  THEN NULL
                                ELSE b.year_of_repair
                            END,
                            CASE
                                WHEN ASCII (b.comments) = 0 -- convert blank to null
                                                            THEN NULL
                                ELSE b.comments
                            END)
                LOG ERRORS INTO bridge_repairs_error_log
                        ('LOAD BRIDGE REPAIRS ' || SYSDATE)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE BRIDGE_REPAIRS_ERROR_LOG';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE BRIDGE_REPAIRS';

    OPEN brdg;

    -- Process first Record
    FETCH brdg INTO b;

    tbridge_id :=
        Get_bridge_id (b.bridge_number, CONVERT_TO_NUMBER (b.year_of_repair));
    Write_it;
    Last_bridge_inserted := b.bridge_number;

    LOOP
        FETCH brdg INTO b;

        EXIT WHEN brdg%NOTFOUND;

        IF b.bridge_number <> last_bridge_inserted
        THEN
            -- first bridge of new group
            tbridge_id :=
                Get_bridge_id (b.bridge_number,
                               CONVERT_TO_NUMBER (b.year_of_repair));
            Write_it;
            Last_bridge_inserted := b.bridge_number;
        ELSE                                           -- same bridge in group
                                                             -- with some data
            IF NOT (    b.year_of_repair IS NULL
                    AND b.repair_done_by IS NULL
                    AND b.scope IS NULL
                    AND b.comments IS NULL)
            THEN
                tbridge_id :=
                    Get_bridge_id (b.bridge_number,
                                   CONVERT_TO_NUMBER (b.year_of_repair));
                Write_it;
                Last_bridge_inserted := b.bridge_number;
            END IF;
        END IF;
    END LOOP;

    -- Last row
    IF b.bridge_number <> last_bridge_inserted
    THEN
        -- first bridge of new group
        tbridge_id :=
            Get_bridge_id (b.bridge_number,
                           CONVERT_TO_NUMBER (b.year_of_repair));
        Write_it;
    ELSE                                               -- same bridge in group
                                                             -- with some data
        IF NOT (    b.year_of_repair IS NULL
                AND b.repair_done_by IS NULL
                AND b.scope IS NULL
                AND b.comments IS NULL)
        THEN
            tbridge_id :=
                Get_bridge_id (b.bridge_number,
                               CONVERT_TO_NUMBER (b.year_of_repair));
            Write_it;
        END IF;
    END IF;

    COMMIT;

    CLOSE brdg;

    SELECT COUNT (*) INTO cntr FROM bridge_repairs;


    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
        OWNER         => 'WH_ASSETS',
        OBJECT_NAME   => 'BRIDGE_REPAIRS',
        object_cnt    => cntr,
        add_cnt       => cntr,
        proc          => $$PLSQL_UNIT,
        start_time    => common_rundate);
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
        RAISE_APPLICATION_ERROR (-20052, SUBSTR (SQLERRM, 1, 400));
END;
/
