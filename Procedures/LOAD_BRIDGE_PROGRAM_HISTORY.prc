CREATE OR REPLACE PROCEDURE load_bridge_program_history
IS
    /**********************************************************************
    This procedure loads the bridge_program_history table with data from InspecTech

    It reads the data from the EXT_PROGRAM_HISTORY external tables

    It does a complete refresh daily (to start with)

    Modification History:

    01-04-2017 SH Initial Version
    04-26-2017 SH Fix bug with NOT and IS NULL in cursors
    07-11-2017 SH Modify cursor to include one row for all bridges to be able to join to workplan review
                  to get the field review comments whether there is program history or not (Tom Farwell request)
   11-25-18 SH Change references of ibridges to ibridges_history WHERE end_date is NULL to facilitate change to new bridge selection criteria
   01-23-23 SH Remove extra blank row for bridges by checking count.  Note program history is a 'repeating column' in assestwise so it is
               difficult to tell which repeating group will actually contain data JIRA DOTDW-686
    **********************************************************************/

    common_rundate   DATE := SYSDATE;
    cntr             NUMBER;
    commit_count     NUMBER := 0;



    CURSOR brdg IS
        SELECT p.bridge_number,
               b.bridge_name,
               b.bridge_id,
               p.ce_cost,
               p.construction_cost,
               p.pe_cost,
               p.program_year,
               p.psn,
               p.row_cost,
               p.scope,
               p.tot_cost
          FROM ext_prog_history  p
               JOIN ibridges_history b ON p.bridge_number = b.bridge_number
         WHERE b.end_date IS NULL
        UNION
        SELECT p.bridge_number,
               b.bridge_name,
               b.bridge_id,
               p.ce_cost,
               p.construction_cost,
               p.pe_cost,
               p.program_year,
               p.psn,
               p.row_cost,
               p.scope,
               p.tot_cost
          FROM ext_prog_history2  p
               JOIN ibridges_history b ON p.bridge_number = b.bridge_number
         WHERE     b.end_date IS NULL
               AND NOT (    program_year IS NULL
                        AND ce_cost IS NULL
                        AND construction_cost IS NULL
                        AND pe_cost IS NULL
                        AND psn IS NULL
                        AND row_cost IS NULL
                        AND scope IS NULL
                        AND tot_cost IS NULL)
        UNION
        SELECT p.bridge_number,
               b.bridge_name,
               b.bridge_id,
               p.ce_cost,
               p.construction_cost,
               p.pe_cost,
               p.program_year,
               p.psn,
               p.row_cost,
               p.scope,
               p.tot_cost
          FROM ext_prog_history3  p
               JOIN ibridges_history b ON p.bridge_number = b.bridge_number
         WHERE     b.end_date IS NULL
               AND NOT (    program_year IS NULL
                        AND ce_cost IS NULL
                        AND construction_cost IS NULL
                        AND pe_cost IS NULL
                        AND psn IS NULL
                        AND row_cost IS NULL
                        AND scope IS NULL
                        AND tot_cost IS NULL)
        ORDER BY 1;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE program_history_error_log';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE bridge_program_history';

    FOR b IN brdg
    LOOP
        cntr := 0;

        SELECT COUNT (*)
          INTO cntr
          FROM EXT_PROG_HISTORY e
         WHERE b.bridge_number = e.bridge_number;

        IF    cntr = 1  -- keep one row per bridge even if there is no data
           OR   ( NOT (b.program_year IS  NULL  -- if there's more than 1 row per bridge, don't keep any null rows
               AND b.ce_cost IS  NULL
               AND b.construction_cost IS  NULL
               AND b.pe_cost IS  NULL
               AND b.psn IS  NULL
               AND b.row_cost IS  NULL
               AND b.scope IS  NULL
               AND b.tot_cost IS  NULL))
        THEN
            INSERT INTO bridge_program_history (bridge_id,
                                                bridge_name,
                                                bridge_number,
                                                ce_cost,
                                                construction_cost,
                                                pe_cost,
                                                program_year,
                                                psn,
                                                row_cost,
                                                scope,
                                                tot_cost)
                     VALUES (
                                b.bridge_id,
                                b.bridge_name,
                                b.bridge_number,
                                CASE
                                    WHEN    b.ce_cost IS NULL
                                         OR ASCII (b.ce_cost) = 0 -- convert blank to null
                                    THEN
                                        NULL
                                    ELSE
                                        Convert_to_number (b.ce_cost)
                                END,
                                CASE
                                    WHEN    b.construction_cost IS NULL
                                         OR ASCII (b.construction_cost) = 0 -- convert blank to null
                                    THEN
                                        NULL
                                    ELSE
                                        Convert_to_number (
                                            b.construction_cost)
                                END,
                                CASE
                                    WHEN    b.pe_cost IS NULL
                                         OR ASCII (b.pe_cost) = 0 -- convert blank to null
                                    THEN
                                        NULL
                                    ELSE
                                        Convert_to_number (b.pe_cost)
                                END,
                                b.program_year,
                                b.psn,
                                CASE
                                    WHEN    b.row_cost IS NULL
                                         OR ASCII (b.row_cost) = 0 -- convert blank to null
                                    THEN
                                        NULL
                                    ELSE
                                        Convert_to_number (b.row_cost)
                                END,
                                b.scope,
                                CASE
                                    WHEN    b.tot_cost IS NULL
                                         OR ASCII (b.tot_cost) = 0 -- convert blank to null
                                    THEN
                                        NULL
                                    ELSE
                                        Convert_to_number (
                                            SUBSTR (b.tot_cost,
                                                    1,
                                                    LENGTH (b.tot_cost) - 1)) -- strip extra space off tot_cost
                                END)
                    LOG ERRORS INTO program_history_ERROR_LOG
                            ('LOAD PROGRAM HISTORY ' || SYSDATE)
                            REJECT LIMIT 100;

            commit_count := commit_count + 1;

            IF commit_count > 10000
            THEN
                COMMIT;
                commit_count := 0;
            END IF;
        END IF;
    END LOOP;

    COMMIT;

    SELECT COUNT (*) INTO cntr FROM bridge_program_history;


    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
        OWNER         => 'WH_ASSETS',
        OBJECT_NAME   => 'BRIDGE_PROGRAM_HISTORY',
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
