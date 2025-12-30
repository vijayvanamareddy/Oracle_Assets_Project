CREATE OR REPLACE PROCEDURE element_yearly_snapshot
/**********************************************************************
This procedure creates the yearly snapshot of the element_history table

It is run yearly on 3/1/yyyy (or at freeze time) to implement the yearly snapshot.

Each row that is current (end date is null) in the element_history table is end-dated, and a new row is
inserted for the next year with a state = 'CURRENT'

It is the first procedure to run, followed by all other yearly_snapshot procedures

3-18-2015 - SH - Initial version
3-05-2016 - SH - add commit code
3-08-2016 - SH - add common error handling code
3-10-2016 - SH - add code to check error log
6-19-2018 - SH - Add column route_type in preparation for adding rail, trail, ferry routes
2-27-2019 - SH - Copy to element_yearly_snapshot
               - Add ROUTE_GROUP, ROUTE_SYSTEM, ROUTE_TYPE
06-03-2019 SH - End date old element outside of loop to avoid large rollback segment generation
05-28-20  SH - Rename column number_of_lanes to number_of_lane_xsections (Tom Marcotte request)
                 The number of lanes can be obtained from the section level column lane_count
               - Add Column GA_TYPE and GA_TYPE_DESCR (Ed Beckworth request)
04-04-21  SH - Remove commit from fetch loop to avoid snapshot too old, rollback segment too small (ora-01555), 
               commit after all rows inserted
**********************************************************************/
IS
BEGIN
    DECLARE
        CURSOR all_elements IS
            SELECT BEGIN_NODE_DESCRIPTION,
                   BEGIN_NODE_ID,
                   COUNTY_CODE,
                   COUNTY_NAME,
                   DIRECTIONAL_SUFFIX,
                   ELEMENT_ID,
                   ELEMENT_LENGTH,
                   ELEMENT_WID,
                   END_DATE,
                   END_NODE_DESCRIPTION,
                   END_NODE_ID,
                   EXISTING,
                   FACTOR_GROUP,
                   GA_TYPE,
                   GA_TYPE_DESCR,
                   MODIFIED_BY,
                   NUMBER_OF_LANE_XSECTIONS,
                   OFFICIAL_MILES,
                   ONE_WAY,
                   ONE_WAY_DESCR,
                   PRIMARY_ROUTE_NAME,
                   PRIMARY_ROUTE_NUMBER,
                   RAMP,
                   RAMP_DESCR,
                   REGION,
                   REGION_DESCR,
                   ROUTE_GROUP,
                   ROUTE_SYSTEM,
                   ROUTE_TYPE,
                   SNAPSHOT_YEAR,
                   START_DATE,
                   STATE,
                   TOWN,
                   TOWN_CODE
              FROM element_history
             WHERE end_date IS NULL;

        rec                      all_elements%ROWTYPE;
        common_run_date          DATE := SYSDATE;
        current_year             NUMBER;
        last_snapshot_year       NUMBER;
        cntr                     NUMBER := 0;
        cntr_updated             NUMBER := 0;
        cntr_added               NUMBER := 0;
        G_owner                  VARCHAR2 (20) := 'WH_ASSETS';
        G_jobname                VARCHAR2 (30) := $$PLSQL_UNIT;
        g_start_time             DATE := SYSDATE;
        g_object                 VARCHAR2 (21) := 'ELEMENT_HISTORY';
        G_SQLMSG                 VARCHAR2 (1000) := NULL;
        V_flat_file_counts_txt   VARCHAR2 (1000) := NULL;
        errlog_count             NUMBER;
        err_log_message          VARCHAR2 (200) := NULL;
    BEGIN
        SELECT MAX (snapshot_year)
          INTO last_snapshot_year
          FROM element_history;

        current_year := last_snapshot_year + 1;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE ELEMENT_ERROR_LOG';

        OPEN all_elements;

        LOOP
            FETCH all_elements INTO rec;

            EXIT WHEN all_elements%NOTFOUND;

            -- Insert new element record
            INSERT INTO element_history (BEGIN_NODE_DESCRIPTION,
                                         BEGIN_NODE_ID,
                                         COUNTY_CODE,
                                         COUNTY_NAME,
                                         CREATED_BY,
                                         DATE_CREATED,
                                         DATE_MODIFIED,
                                         DIRECTIONAL_SUFFIX,
                                         ELEMENT_ID,
                                         ELEMENT_LENGTH,
                                         ELEMENT_WID,
                                         END_DATE,
                                         END_NODE_DESCRIPTION,
                                         END_NODE_ID,
                                         EXISTING,
                                         FACTOR_GROUP,
                                         GA_TYPE,
                                         GA_TYPE_DESCR,
                                         MODIFIED_BY,
                                         NUMBER_OF_LANE_XSECTIONS,
                                         OFFICIAL_MILES,
                                         ONE_WAY,
                                         ONE_WAY_DESCR,
                                         PRIMARY_ROUTE_NAME,
                                         PRIMARY_ROUTE_NUMBER,
                                         RAMP,
                                         RAMP_DESCR,
                                         REGION,
                                         REGION_DESCR,
                                         ROUTE_GROUP,
                                         ROUTE_SYSTEM,
                                         ROUTE_TYPE,
                                         SNAPSHOT_YEAR,
                                         START_DATE,
                                         STATE,
                                         TOWN,
                                         TOWN_CODE)
                 VALUES (REC.BEGIN_NODE_DESCRIPTION,
                         REC.BEGIN_NODE_ID,
                         REC.COUNTY_CODE,
                         REC.COUNTY_NAME,
                         'ELEMENT_YEARLY_SNAPSHOT',              -- created by
                         common_run_date,                      -- date created
                         NULL,                               -- DATE_MODIFIED,
                         REC.DIRECTIONAL_SUFFIX,
                         REC.ELEMENT_ID,
                         REC.ELEMENT_LENGTH,
                         assets_sequence.NEXTVAL,              -- ELEMENT_WID,
                         NULL,                                    -- END_DATE,
                         REC.END_NODE_DESCRIPTION,
                         REC.END_NODE_ID,
                         REC.EXISTING,
                         REC.FACTOR_GROUP,
                         REC.GA_TYPE,
                         REC.GA_TYPE_DESCR,
                         NULL,                               --   MODIFIED_BY,
                         REC.NUMBER_OF_LANE_XSECTIONS,
                         REC.OFFICIAL_MILES,
                         REC.ONE_WAY,
                         REC.ONE_WAY_DESCR,
                         REC.PRIMARY_ROUTE_NAME,
                         REC.PRIMARY_ROUTE_NUMBER,
                         REC.RAMP,
                         REC.RAMP_DESCR,
                         REC.REGION,
                         REC.REGION_DESCR,
                         REC.ROUTE_GROUP,
                         REC.ROUTE_SYSTEM,
                         REC.ROUTE_TYPE,
                         CURRENT_YEAR,                       -- SNAPSHOT_YEAR,
                         common_run_date,                       -- START_DATE,
                         'CURRENT',                                  -- STATE,
                         REC.TOWN,
                         REC.TOWN_CODE)
                    LOG ERRORS INTO element_error_log
                            ('ELEMENT_YEARLY_SNAPSHOT ' || SYSDATE)
                            REJECT LIMIT 100;

            cntr_added := cntr_added + 1;
        END LOOP;

        CLOSE all_elements;

        COMMIT;

        -- Set counter updated for reporting

        SELECT COUNT (*)
          INTO cntr_updated
          FROM element_history
         WHERE snapshot_year = last_snapshot_year AND end_date IS NULL;


        -- End date old element
        UPDATE element_history
           SET end_date = common_run_date,
               date_modified = common_run_date,
               modified_by = 'YEARLY_SNAPSHOT',
               state = 'PAST'
         WHERE snapshot_year = last_snapshot_year AND end_date IS NULL;

        COMMIT;

        SELECT COUNT (*) INTO errlog_count FROM element_error_log;

        IF errlog_count > 0
        THEN
            BEGIN
                err_log_message :=
                    'Unexpected Data Quality Issues in element_error_log ';

                INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                                ERR_MODULE,
                                                ERR_OID,
                                                ERR_MESSAGE)
                     VALUES (SYSDATE,
                             'element_yearly_snapshot',
                             'WH_ASSETS',
                             err_log_message);

                COMMIT;
                wh_common.pkg_common_utilities.exit_and_report (
                    $$PLSQL_UNIT,
                    'FAILURE',
                    err_log_message);
                RAISE_APPLICATION_ERROR (
                    -20010,
                    $$PLSQL_UNIT || ' ' || err_log_message);
            END;
        ELSE                                                 -- Successful Run
            BEGIN
                SELECT COUNT (*) INTO cntr FROM element_history;

                WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
                    OWNER         => G_OWNER,
                    OBJECT_NAME   => g_object,
                    object_cnt    => cntr,
                    add_cnt       => cntr_added,
                    update_cnt    => cntr_updated,
                    proc          => $$PLSQL_UNIT,
                    start_time    => g_start_time);

                WH_COMMON.PKG_COMMON_UTILITIES.EXIT_AND_REPORT (
                    g_jobname,
                    'NORMAL',
                    V_flat_file_counts_txt);
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
END;
/
