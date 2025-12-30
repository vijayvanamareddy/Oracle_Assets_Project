CREATE OR REPLACE PROCEDURE load_cross_section_staging
IS
    /**********************************************************************
    This procedure loads the CROSS_SECTION_STAGING table which contains the shoulders
    and lane information positioned on the left/right based on the direction
    of the element on the route from the GIS system.

    It truncates the table and re-loads it.

    01-25-2019 SH  Initial Version
    02-05-2019 SH  Add section_id and element_wid
    03-26-2019 SH  Moved from dev to test
    04-26-2019 SH  Modify to load section staging table to implement history and create yearly snapshot
    07-06-2019 SH  Add sidewalks
    **********************************************************************/



    commit_count   NUMBER (7) := 0;
    cntr           NUMBER (7) := 0;

    g_start_time   DATE := SYSDATE;
    g_owner        VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname      VARCHAR2 (30) := 'LOAD_CROSS_SECTION_STAGING';
    g_object       VARCHAR2 (30) := 'CROSS_SECTION_STAGING';
    g_sqlmsg       VARCHAR2 (500) := NULL;

    telement_wid   NUMBER;
    tsection_id    NUMBER;

    CURSOR crs
    IS
        SELECT route_number,
               element_id,
               begin_offset,
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
               right_sidewalk_width
          FROM v_wh_sections_allroutes@gis;

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
        -- Gets the section id,  from the sections table
        -- using the element id,  begin and end offset
        counter   NUMBER;
        err       VARCHAR2 (100);
        sec_id    NUMBER := 0;
    BEGIN
        counter := 0;

        SELECT COUNT (*)     -- determine if offset lies on a section boundary
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
                 VALUES ('cross_section_staging',
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
                 VALUES ('Cross_Section_Staging',
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
    EXECUTE IMMEDIATE 'TRUNCATE TABLE CROSS_SECTION_STAGING';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE CROSS_SECTIONS_ERROR_LOG';


    FOR c IN crs
    LOOP
        telement_wid := Get_element_wid (c.element_id);
        tsection_id :=
            Get_section_id (c.element_id, c.begin_offset, c.end_offset);

        INSERT INTO cross_section_staging (begin_offset,
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
                                           section_id)
             VALUES (c.begin_offset,
                     c.element_id,
                     telement_wid,
                     c.end_offset,
                     c.left_lane_crosssection,
                     c.left_shoulder_type,
                     c.left_shoulder_type_descr,
                     c.left_shoulder_width,
                     c.left_sidewalk_type,
                     c.left_sidewalk_type_descr,
                     c.left_sidewalk_width,
                     c.right_lane_crosssection,
                     c.right_shoulder_type,
                     c.right_shoulder_type_descr,
                     c.right_shoulder_width,
                     c.right_sidewalk_type,
                     c.right_sidewalk_type_descr,
                     c.right_sidewalk_width,
                     c.route_number,
                     tsection_id)
                LOG ERRORS INTO CROSS_SECTIONS_ERROR_LOG
                        ('LOAD_CROSS_SECTIONS ' || SYSDATE)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;

    SELECT COUNT (*) INTO cntr FROM cross_section_staging;

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
