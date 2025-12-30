CREATE OR REPLACE PROCEDURE cross_section_weekly_refresh (
    staging_already_loaded   IN VARCHAR2 := 'N',
    cntr_threshold           IN NUMBER := 300000)
IS
    /**********************************************************************
    This procedure loads the cross_section_staging table & compares it to the cross_section_history table
    for the weekly refresh.  New cross sections are added.  Old cross sections are 'RETIRED'.

    Changed cross sections cause the current cross sections row to be updated with the new values.

    This should be run immediately after section_weekly_refresh.

    04-30-2019 SH - Initial version
    05-30-2019 SH - Do not create new section_id if there is no element_id, begin/end offset
    06-03-2019 SH - Update the section_id of existing cross section that has changed
    07-06-2020 SH - Add sidewalks
    **********************************************************************/


    CURSOR xsection_changes
    IS
        SELECT begin_offset,
               element_id,
               element_wid,
               end_offset,
               left_lane_crosssection,
               left_shoulder_type,
               left_shoulder_type_descr,
               left_shoulder_width,
               left_sidewalk_type,
               left_sidewalk_type_descr,
               left_sidewalk_width,
               right_lane_crosssection,
               right_shoulder_type,
               right_shoulder_type_descr,
               right_shoulder_width,
               right_sidewalk_type,
               right_sidewalk_type_descr,
               right_sidewalk_width,
               route_number,
               section_id
          FROM cross_section_staging
        MINUS
        SELECT begin_offset,
               element_id,
               element_wid,
               end_offset,
               left_lane_crosssection,
               left_shoulder_type,
               left_shoulder_type_descr,
               left_shoulder_width,
               left_sidewalk_type,
               left_sidewalk_type_descr,
               left_sidewalk_width,
               right_lane_crosssection,
               right_shoulder_type,
               right_shoulder_type_descr,
               right_shoulder_width,
               right_sidewalk_type,
               right_sidewalk_type_descr,
               right_sidewalk_width,
               route_number,
               section_id
          FROM cross_section_history
         WHERE end_date IS NULL;

    CURSOR retired_cross_sections
    IS
        SELECT route_number,
               element_id,
               begin_offset,
               end_offset
          FROM cross_section_history
         WHERE end_date IS NULL AND state = 'CURRENT'
        MINUS
        SELECT route_number,
               element_id,
               begin_offset,
               end_offset
          FROM cross_section_staging;


    cntr                       NUMBER (9) := 0;
    row_cntr                   NUMBER := 0;
    threshold_message          VARCHAR2 (200) := NULL;
    cntr_updated               NUMBER (9) := 0;
    cntr_added                 NUMBER (9) := 0;
    cntr_replaced              NUMBER := 0;
    g_owner                    VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                  VARCHAR2 (30) := 'CROSS_SECTION_WKLY_REFRSH';
    g_object                   VARCHAR2 (20) := 'CROSS_SECTION_HSTORY';
    g_sqlmsg                   VARCHAR2 (500) := NULL;
    V_flat_file_counts_txt     VARCHAR2 (1000) := NULL;
    initial_number_lanes       NUMBER (5) := 0;
    current_element_wid        NUMBER;
    current_begin_node_descr   VARCHAR2 (200) := NULL;
    current_end_node_descr     VARCHAR2 (200) := NULL;
    g_start_time               DATE := SYSDATE;
    surrogate_key              NUMBER;
    current_year               NUMBER;
    errlog_count               NUMBER;
    err_log_message            VARCHAR2 (200) := NULL;
    commit_counter             NUMBER := 0;
BEGIN
    SELECT MAX (snapshot_year)
      INTO current_year
      FROM cross_section_history
     WHERE STATE = 'CURRENT';

    IF staging_already_loaded = 'N'
    THEN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE cross_sections_error_log';

        load_cross_section_staging;
        cross_section_diffs;
    END IF;

    FOR rec IN xsection_changes
    LOOP
        cntr := cntr + 1;
    END LOOP;

    IF cntr < cntr_threshold
    THEN
        FOR rec IN xsection_changes
        LOOP
            SELECT COUNT (*)
              INTO row_cntr
              FROM cross_section_history
             WHERE     element_id = rec.element_id
                   AND begin_offset = rec.begin_offset
                   AND end_offset = rec.end_offset
                   AND route_number = rec.route_number
                   AND end_date IS NULL
                   AND STATE = 'CURRENT';


            IF row_cntr = 1 -- update the existing cross section that has some attributes changed
            THEN
                BEGIN
                    UPDATE cross_section_history
                       SET date_modified = g_start_time,
                           left_lane_crosssection =
                               rec.left_lane_crosssection,
                           left_shoulder_type = rec.left_shoulder_type,
                           left_shoulder_type_descr =
                               rec.left_shoulder_type_descr,
                           left_shoulder_width = rec.left_shoulder_width,
                           left_sidewalk_type = rec.left_sidewalk_type,
                           left_sidewalk_type_descr =
                               rec.left_sidewalk_type_descr,
                           left_sidewalk_width = rec.left_sidewalk_width,
                           modified_by = g_jobname,
                           right_lane_crosssection =
                               rec.right_lane_crosssection,
                           right_shoulder_type = rec.right_shoulder_type,
                           right_shoulder_type_descr =
                               rec.right_shoulder_type_descr,
                           right_shoulder_width = rec.right_shoulder_width,
                           right_sidewalk_type = rec.right_sidewalk_type,
                           right_sidewalk_type_descr =
                               rec.right_sidewalk_type_descr,
                           right_sidewalk_width = rec.right_sidewalk_width,
                           route_number = rec.route_number,
                           section_id = rec.section_id
                     WHERE     element_id = rec.element_id
                           AND begin_offset = rec.begin_offset
                           AND end_offset = rec.end_offset
                           AND route_number = rec.route_number
                           AND end_date IS NULL
                       LOG ERRORS INTO cross_sections_error_log
                               (   'CROSS SECTIONS WEEKLY REFRESH UPDATE '
                                || SYSDATE)
                               REJECT LIMIT 100;

                    cntr_updated := cntr_updated + 1;

                    commit_counter := commit_counter + 1;

                    IF commit_counter > 1000
                    THEN
                        COMMIT;
                        commit_counter := 0;
                    END IF;
                END;
            ELSE                 -- add a new section not yet in the data mart
                BEGIN
                    cntr_added := cntr_added + 1;

                    INSERT INTO cross_section_history (
                                    begin_offset,
                                    created_by,
                                    date_created,
                                    date_modified,
                                    element_id,
                                    element_wid,
                                    end_date,
                                    end_offset,
                                    left_lane_crosssection,
                                    left_shoulder_type,
                                    left_shoulder_type_descr,
                                    left_shoulder_width,
                                    left_sidewalk_type,
                                    left_sidewalk_type_descr,
                                    left_sidewalk_width,
                                    modified_by,
                                    right_lane_crosssection,
                                    right_shoulder_type,
                                    right_shoulder_type_descr,
                                    right_shoulder_width,
                                    right_sidewalk_type,
                                    right_sidewalk_type_descr,
                                    right_sidewalk_width,
                                    route_number,
                                    section_id,
                                    snapshot_year,
                                    start_date,
                                    state)
                             VALUES (rec.begin_offset,
                                     g_jobname,                 -- CREATED_BY,
                                     g_start_time,            -- DATE_CREATED,
                                     NULL,                   -- DATE_MODIFIED,
                                     rec.element_id,
                                     rec.element_wid,
                                     NULL,                        -- END_DATE,
                                     rec.end_offset,
                                     rec.left_lane_crosssection,
                                     rec.left_shoulder_type,
                                     rec.left_shoulder_type_descr,
                                     rec.left_shoulder_width,
                                     rec.left_sidewalk_type,
                                     rec.left_sidewalk_type_descr,
                                     rec.left_sidewalk_width,
                                     NULL,                    --  MODIFIED_BY,
                                     rec.right_lane_crosssection,
                                     rec.right_shoulder_type,
                                     rec.right_shoulder_type_descr,
                                     rec.right_shoulder_width,
                                     rec.right_sidewalk_type,
                                     rec.right_sidewalk_type_descr,
                                     rec.right_sidewalk_width,
                                     rec.route_number,
                                     rec.section_id,            -- SECTION_ID,
                                     current_year,           -- SNAPSHOT_YEAR,
                                     g_start_time,             --  START_DATE,
                                     'CURRENT')                     --  STATE)
                            LOG ERRORS INTO cross_sections_error_log
                                    (   'CROSS SECTIONS WEEKLY REFRESH INSERT '
                                     || SYSDATE)
                                    REJECT LIMIT 100;

                    commit_counter := commit_counter + 1;

                    IF commit_counter > 1000
                    THEN
                        COMMIT;
                        commit_counter := 0;
                    END IF;

                    INSERT INTO cross_section_changes            -- log insert
                                                      (section_id,
                                                       element_id,
                                                       begin_offset,
                                                       end_offset,
                                                       change_type,
                                                       change_date,
                                                       column_name,
                                                       route_number,
                                                       modified_by,
                                                       old_value,
                                                       new_value)
                         VALUES (rec.section_id,
                                 rec.element_id,
                                 rec.begin_offset,
                                 rec.end_offset,
                                 'I',
                                 g_start_time,
                                 NULL,
                                 rec.route_number,
                                 g_jobname,
                                 NULL,
                                 NULL);
                END;                                         -- insert new row
            END IF;                                                -- cntr > 0
        END LOOP;                           -- FOR rec IN section_changes loop


        FOR r IN retired_cross_sections
        LOOP
            BEGIN
                SELECT COUNT (*)
                  INTO row_cntr
                  FROM cross_section_history
                 WHERE     element_id = r.element_id
                       AND begin_offset = r.begin_offset
                       AND end_offset = r.end_offset
                       AND route_number = r.route_number -- In cross_section_history there is one row per route per section
                       AND end_date IS NULL;

                IF row_cntr = 1
                THEN
                    BEGIN
                        SELECT section_id
                          INTO surrogate_key
                          FROM cross_section_history
                         WHERE     element_id = r.element_id
                               AND begin_offset = r.begin_offset
                               AND end_offset = r.end_offset
                               AND end_date IS NULL
                               AND route_number = r.route_number;



                        UPDATE cross_section_history
                           SET end_date = g_start_time,
                               date_modified = g_start_time,
                               state = 'RETIRED',
                               modified_by = g_jobname
                         WHERE     element_id = r.element_id
                               AND begin_offset = r.begin_offset
                               AND end_offset = r.end_offset
                               AND route_number = r.route_number
                               AND end_date IS NULL;


                        cntr_replaced := cntr_replaced + 1;
                        commit_counter := commit_counter + 1;

                        IF commit_counter > 1000
                        THEN
                            COMMIT;
                            commit_counter := 0;
                        END IF;

                        INSERT INTO cross_section_changes        -- log delete
                                                          (section_id,
                                                           element_id,
                                                           begin_offset,
                                                           end_offset,
                                                           change_type,
                                                           change_date,
                                                           column_name,
                                                           route_number,
                                                           modified_by,
                                                           old_value,
                                                           new_value)
                             VALUES (surrogate_key,
                                     r.element_id,
                                     r.begin_offset,
                                     r.end_offset,
                                     'D',
                                     g_start_time,
                                     NULL,
                                     r.route_number,
                                     g_jobname,
                                     NULL,
                                     NULL);
                    END;
                ELSE
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
                                                 COLUMN_VALUE3,
                                                 column_name4,
                                                 column_value4)
                         VALUES ('CROSS SECTIONS_HISTORY',
                                 'Error Retiring Row',
                                 g_jobname,
                                 g_start_time,
                                 'QUALITY',
                                 'ELEMENT_ID',
                                 R.element_id,
                                 'BEGIN_OFFSET',
                                 r.begin_offset,
                                 'END_OFFSET',
                                 r.end_offset,
                                 'ROUTE_NUMBER',
                                 r.route_number);
                END IF;
            END;
        END LOOP;

        COMMIT;

        -- Check error log

        SELECT COUNT (*) INTO errlog_count FROM cross_sections_error_log;

        IF errlog_count > 0
        THEN
            BEGIN
                err_log_message :=
                    'Unexpected Data Quality Issues in Cross Sections error log ';

                INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                                ERR_MODULE,
                                                ERR_OID,
                                                ERR_MESSAGE)
                     VALUES (SYSDATE,
                             g_jobname,
                             g_owner,
                             err_log_message);

                INSERT INTO data_exceptions (TABLE_NAME,
                                             ERROR_CONDITION,
                                             TEST_PROCEDURE,
                                             TEST_DATE,
                                             ASSESSMENT)
                     VALUES ('cross_section_error_log',
                             'Invalid data - check error log',
                             g_jobname,
                             g_start_time,
                             'QUALITY');

                COMMIT;
            END;
        END IF;



        -- normal processing

        SELECT COUNT (*) INTO cntr FROM cross_section_history;

        V_flat_file_counts_txt :=
               'CROSS_SECTION_HISTORY: '
            || 'Total Rows: '
            || cntr
            || ' Added: '
            || cntr_added
            || ' Updated/New Row Added: '
            || cntr_updated
            || '  ';

        WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
            OWNER         => G_OWNER,
            OBJECT_NAME   => g_object,
            object_cnt    => cntr,
            add_cnt       => cntr_added,
            update_cnt    => cntr_updated,
            proc          => $$PLSQL_UNIT,
            start_time    => g_start_time);

        wh_common.pkg_common_utilities.EXIT_AND_REPORT (
            g_jobname,
            'NORMAL',
            V_flat_file_counts_txt);
    ELSE                                                     -- Over Threshold
        threshold_message :=
               'Unexpected High Update Volume in Cross Sections: '
            || cntr
            || ' Update Threshold: '
            || cntr_threshold
            || '. ';

        INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                        ERR_MODULE,
                                        ERR_OID,
                                        ERR_MESSAGE)
             VALUES (SYSDATE,
                     g_jobname,
                     g_owner,
                     threshold_message);

        COMMIT;

        wh_common.pkg_common_utilities.exit_and_report ($$PLSQL_UNIT,
                                                        'FAILURE',
                                                        threshold_message);
    END IF;

    COMMIT;
EXCEPTION
    WHEN OTHERS
    THEN
        G_SQLMSG := SUBSTR (SQLERRM, 1, 400);
        wh_common.pkg_common_utilities.update_whse_log (
            g_owner,
            g_object,
            NULL,
            NULL,
            NULL,
            NULL,
            'Error during ' || g_jobname || ': ' || G_SQLMSG,
            'Failed');
        wh_common.pkg_common_utilities.exit_and_report (
            g_jobname,
            'FAILURE',
            g_jobname || ' - ' || G_SQLMSG);
        RAISE_APPLICATION_ERROR (-20020, $$PLSQL_UNIT || ' ' || G_SQLMSG);
END;
/
