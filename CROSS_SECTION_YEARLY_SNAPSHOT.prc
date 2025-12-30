CREATE OR REPLACE PROCEDURE cross_section_yearly_snapshot
/**********************************************************************
This procedure creates the yearly snapshot of the cross_section_history table

It is run yearly on 3/1/yyyy to implement the yearly snapshot.
It is run, after section_yearly_snapshot


05-01-2019 SH - Initial Version
06-03-2019 SH - End date old xsection outside of loop to avoid large rollback segment generation
07-06-2020 SH - Add Sidewalks
04-04-2021 SH - Remove commit from fetch loop to avoid snapshot too old, rollback segment too small (ora-01555), 
               commit after all rows inserted
**********************************************************************/
IS
    CURSOR all_xsections
    IS
        SELECT begin_offset,
               element_id,
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
               state,
               snapshot_year,
               start_date,
               end_date
          FROM cross_section_history
         WHERE end_date IS NULL AND state = 'CURRENT';

    rec                      all_xsections%ROWTYPE;
 
    telement_wid             NUMBER;
    tsection_id              NUMBER;
    common_run_date          DATE := SYSDATE;
    current_year             NUMBER;
    last_snapshot_year       NUMBER;
    cntr                     NUMBER := 0;
    cntr_updated             NUMBER := 0;
    cntr_added               NUMBER := 0;
    g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                VARCHAR2 (30) := $$PLSQL_UNIT;
    g_start_time             DATE := SYSDATE;
    g_object                 VARCHAR2 (21) := 'CROSS_SECTION_HISTORY';
    g_SQLMSG                 VARCHAR2 (1000) := NULL;
    V_flat_file_counts_txt   VARCHAR2 (1000) := NULL;
    errlog_count             NUMBER := 0;
    err_log_message          VARCHAR2 (200) := NULL;

    FUNCTION Get_element_wid (el_id IN NUMBER)
        RETURN NUMBER
    IS
        ele_wid   NUMBER;                               -- Get the element_wid
        err       VARCHAR2 (100);
    BEGIN
        SELECT element_wid
          INTO ele_wid
          FROM element_history h
         WHERE h.element_id = el_id AND h.state = 'CURRENT';

        RETURN ele_wid;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
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
                                         COLUMN_VALUE2)
                 VALUES ('cross_sections',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'FUNCTION',
                         'Get_element_wid',
                         'ELEMENT_NUMBER',
                         el_id);

            RETURN NULL;
    END;

    FUNCTION Get_section_id (el_id    IN NUMBER,
                             boffst   IN NUMBER,
                             eoffst   IN NUMBER)
        RETURN NUMBER
    IS
        -- Gets the section id, from the sections view
        -- using the element id, begin, and end offset
        counter   NUMBER;
        err       VARCHAR2 (100);
        sec_id    NUMBER := 0;
    BEGIN
        counter := 0;

        SELECT COUNT (*)
          INTO counter
          FROM sections s
         WHERE     el_id = s.element_id
               AND boffst = s.begin_offset
               AND eoffst = S.end_offset;

        IF counter = 1
        THEN
            SELECT s.section_id
              INTO sec_id
              FROM sections s
             WHERE     el_id = s.element_id
                   AND boffst = s.begin_offset
                   AND eoffst = S.end_offset;
        ELSE
            err := 'No matching section ID';

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
                 VALUES ('cross_sections',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'PROCEDURE',
                         'Get_section_id',
                         'ELEMENT_ID',
                         EL_ID,
                         'OFFSETS',
                         boffst || ' ' || eoffst);
        END IF;

        RETURN sec_id;
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
                 VALUES ('Cross_sections',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'PROCEDURE',
                         'Get_section_id',
                         'ELEMENT_ID',
                         EL_ID,
                         'OFFSET',
                         boffst || ' ' || eoffst);
    END;
BEGIN
    SELECT MAX (snapshot_year)
      INTO last_snapshot_year
      FROM cross_section_history;

    current_year := last_snapshot_year + 1;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE cross_sections_error_log';

    OPEN all_xsections;

    LOOP
        FETCH all_xsections INTO rec;

        EXIT WHEN all_xsections%NOTFOUND;

        telement_wid := Get_element_wid (rec.element_id);
        tsection_id :=
            Get_section_id (rec.element_id, rec.begin_offset, rec.end_offset);

        -- Insert new cross section record
        INSERT INTO cross_section_history (begin_offset,
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
                     'XSECTION_YEARLY_SNAPSHOT',                -- CREATED_BY,
                     common_run_date,                         -- DATE_CREATED,
                     NULL,                                   -- DATE_MODIFIED,
                     rec.element_id,
                     telement_wid,
                     NULL,                                        -- END_DATE,
                     rec.end_offset,
                     rec.left_lane_crosssection,
                     rec.left_shoulder_type,
                     rec.left_shoulder_type_descr,
                     rec.left_shoulder_width,
                     rec.left_sidewalk_type,
                     rec.left_sidewalk_type_descr,
                     rec.left_sidewalk_width,
                     NULL,                                     -- modified_by,
                     rec.right_lane_crosssection,
                     rec.right_shoulder_type,
                     rec.right_shoulder_type_descr,
                     rec.right_shoulder_width,
                     rec.right_sidewalk_type,
                     rec.right_sidewalk_type_descr,
                     rec.right_sidewalk_width,
                     rec.route_number,
                     tsection_id,
                     current_year,                           -- SNAPSHOT_YEAR,
                     common_run_date,                           -- START_DATE,
                     'CURRENT')                                      -- STATE)
                LOG ERRORS INTO cross_sections_error_log
                        ('XSECTIONS YEARLY SNAPSHOT ' || SYSDATE)
                        REJECT LIMIT 100;

        cntr_added := cntr_added + 1;
    END LOOP;

    CLOSE all_xsections;

    COMMIT;

    -- Set counter updated for reporting

    SELECT COUNT (*)
      INTO cntr_updated
      FROM cross_section_history
     WHERE snapshot_year = last_snapshot_year AND end_date IS NULL;


    -- End date old xsection
    UPDATE cross_section_history
       SET end_date = common_run_date,
           date_modified = common_run_date,
           modified_by = 'YEARLY_SNAPSHOT',
           state = 'PAST'
     WHERE snapshot_year = last_snapshot_year AND end_date IS NULL;

    COMMIT;

    SELECT COUNT (*) INTO errlog_count FROM cross_sections_error_log;

    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in sections error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         g_jobname,
                         g_owner,
                         err_log_message);

            COMMIT;
            wh_common.pkg_common_utilities.exit_and_report ($$PLSQL_UNIT,
                                                            'FAILURE',
                                                            err_log_message);
            RAISE_APPLICATION_ERROR (-20020, $$PLSQL_UNIT || ' ' || G_SQLMSG);
        END;
    ELSE                                                     -- Successful Run
        BEGIN
            SELECT COUNT (*) INTO cntr FROM cross_section_history;

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
        G_SQLMSG := SUBSTR (SQLERRM, 1, 400);
        wh_common.pkg_common_utilities.update_whse_log (
            OWNER         => G_OWNER,
            OBJECT_NAME   => g_object,
            object_cnt    => cntr,
            add_cnt       => cntr_added,
            update_cnt    => cntr_updated,
            proc          => $$PLSQL_UNIT,
            start_time    => g_start_time,
            msg           => 'Error during ' || g_jobname || ': ' || G_SQLMSG,
            status        => 'Failure');
        wh_common.pkg_common_utilities.exit_and_report (
            g_jobname,
            'FAILURE',
            g_jobname || ' - ' || G_SQLMSG);
        RAISE_APPLICATION_ERROR (-20020, $$PLSQL_UNIT || ' ' || G_SQLMSG);
END;
/
