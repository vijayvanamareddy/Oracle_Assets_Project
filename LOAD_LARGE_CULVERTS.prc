CREATE OR REPLACE PROCEDURE load_large_culverts
IS
    /**********************************************************************
    This procedure loads the large_culverts table from the GIS system.

    It truncates the table and re-loads it weekly.

    01-21-21 SH  Initial Version
    09-27-22 SG  Convert asset_sys_id to CHAR as can't join to asset_number in project_locations from Oracle Analytics
  
    **********************************************************************/



    commit_count   NUMBER (7) := 0;
    cntr           NUMBER (7) := 0;

    g_start_time   DATE := SYSDATE;
    g_owner        VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname      VARCHAR2 (30) := 'LOAD_LARGE_CULVERTS';
    g_object       VARCHAR2 (20) := 'LARGE_CULVERTS';
    g_sqlmsg       VARCHAR2 (500) := NULL;

   
    sect_id        NUMBER;
 
    ttown_name1     VARCHAR2(40);
    ttown_code1     NUMBER;
    ttown_name2     VARCHAR2(40);
    ttown_code2     NUMBER;
    tnode_id        NUMBER;

    CURSOR lg_culv IS
        SELECT ADD_LENGTH,
               ADD_LEN_ID,
               ASSET_SYS_ID,
               BARREL_CONDITION,
               COND_ID AS BARREL_CONDITION_ID,
               LENGTH AS BARREL_LENGTH_FT,
               BARREL_STRUCTURE_TYPE,
               ELEMENTID AS CULVERT_ELEMENT_ID,
               CUL_TYPE_ID AS CULVERT_TYPE_ID,
               DEPTH_OF_COVER AS DEPTH_OF_COVER_FT,
               DESCR AS DESCRIPTION,
               LINK_ID AS ELEMENT_ID,
               INSPECTOR,
               INSTALL_DATE,
               LAST_INSPECT_DATE AS LAST_INSPECTION_DATE,
               Y_LAT AS LATITUDE,
               X_LON AS LONGITUDE,
               CREW AS MAINTENANCE_CREW,
               UNIT_DESCR AS MAINTENANCE_CREW_NAME,
               BMP AS MILEPOINT,
               MODIFIED_BY,
               MODIFIED_DATE,
               NOTES,
               BEGIN_OFFSET AS OFFSET,
               REGION,
               ROUTE AS ROUTE_NUMBER,
               SIDE_OF_ROAD,
               SKEW_ANGLE,
               SPANS AS SPANS_NUMBER,
               SPAN_HEIGHT AS SPAN_HEIGHT_IN,
               SPAN_WIDTH AS SPAN_WIDTH_IN,
               BEGIN_TOWN AS TOWN,
               BEGIN_TOWN_ID AS TOWN_CODE,
               UNIT_ID
          FROM CULVERTS_LARGE@GIS;



    FUNCTION Get_section_id (el_id IN NUMBER, offst IN NUMBER)
        RETURN NUMBER
    IS
        -- Gets the section id,  from the sections table
        -- using the element id/  offset from crash
        counter   NUMBER;
        err       VARCHAR2 (100);
        sec_id    NUMBER := -1;
    BEGIN
        counter := 0;

        SELECT COUNT (*)     -- determine if offset lies on a section boundary
          INTO counter
          FROM sections s
         WHERE     el_id = s.element_id
               AND ROUND (offst, 2) >= s.begin_offset
               AND ROUND (offst, 2) <= S.end_offset;

        IF counter = 0                -- offset is out of range of the element
        THEN
            sec_id := -1;
        END IF;

        IF counter = 1                            -- not on a section boundary
        THEN
            SELECT s.section_id
              INTO sec_id
              FROM sections s
             WHERE     el_id = s.element_id
                   AND ROUND (offst, 2) >= s.begin_offset
                   AND ROUND (offst, 2) <= s.end_offset;
        END IF;

        IF counter > 1 -- on a section boundary,  the second section is chosen
        THEN
            SELECT s.section_id
              INTO sec_id
              FROM sections s
             WHERE     el_id = s.element_id
                   AND ROUND (offst, 2) >= S.BEGIN_OFFSET
                   AND ROUND (offst, 2) < S.END_OFFSET;
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
                 VALUES ('LARGE_CULVERTS',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'PROCEDURE',
                         'Get_section_id',
                         'ELEMENT_ID',
                         EL_ID,
                         'OFFSET',
                         offst);
    END;
    
  

BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE LARGE_CULVERTS';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE LARGE_CULVERTS_ERROR_LOG';



    FOR lc IN lg_culv
    LOOP
        

        sect_id := NULL;
        sect_id := Get_section_id (lc.element_id, lc.offset);
 
     
        INSERT INTO LARGE_CULVERTS (ADD_LENGTH,
                                    ADD_LEN_ID,
                                    ASSET_SYS_ID,
                                    BARREL_CONDITION,
                                    BARREL_CONDITION_ID,
                                    BARREL_LENGTH_FT,
                                    BARREL_STRUCTURE_TYPE,
                                    CULVERT_ELEMENT_ID,
                                    CULVERT_TYPE_ID,
                                    DEPTH_OF_COVER_FT,
                                    DESCRIPTION,
                                    ELEMENT_ID,
                                    INSPECTOR,
                                    INSTALL_DATE,
                                    LAST_INSPECTION_DATE,
                                    LATITUDE,
                                    LONGITUDE,
                                    MAINTENANCE_CREW,
                                    MAINTENANCE_CREW_NAME,
                                    MILEPOINT,
                                    MODIFIED_BY,
                                    MODIFIED_DATE,
                                    NOTES,
                                    OFFSET,
                                    REGION,
                                    ROUTE_NUMBER,
                                    SECTION_ID,
                                    SIDE_OF_ROAD,
                                    SKEW_ANGLE,
                                    SPANS_NUMBER,
                                    SPAN_HEIGHT_IN,
                                    SPAN_WIDTH_IN,
                                    TOWN,
                                    TOWN_CODE,
                                    UNIT_ID)
             VALUES (LC.ADD_LENGTH,
                     LC.ADD_LEN_ID,
                     to_char(LC. ASSET_SYS_ID),
                     LC.BARREL_CONDITION,
                     LC.BARREL_CONDITION_ID,
                     LC.BARREL_LENGTH_FT,
                     LC.BARREL_STRUCTURE_TYPE,
                     LC.CULVERT_ELEMENT_ID,
                     LC.CULVERT_TYPE_ID,
                     LC.DEPTH_OF_COVER_FT,
                     LC.DESCRIPTION,
                     LC.ELEMENT_ID,
                     LC.INSPECTOR,
                     LC.INSTALL_DATE,
                     LC.LAST_INSPECTION_DATE,
                     LC.LATITUDE,
                     LC.LONGITUDE,
                     LC.MAINTENANCE_CREW,
                     LC.MAINTENANCE_CREW_NAME,
                     LC.MILEPOINT,
                     LC.MODIFIED_BY,
                     LC.MODIFIED_DATE,
                     LC.NOTES,
                     LC.OFFSET,
                     LC.REGION,
                     LC.ROUTE_NUMBER,
                     sect_id,
                     LC.SIDE_OF_ROAD,
                     LC.SKEW_ANGLE,
                     LC.SPANS_NUMBER,
                     LC.SPAN_HEIGHT_IN,
                     LC.SPAN_WIDTH_IN,
                     LC.TOWN,
                     LC.TOWN_CODE,
                     LC.UNIT_ID)
                LOG ERRORS INTO large_culverts_error_log
                        ('Load Large Culverts ' || SYSDATE)
                        REJECT LIMIT 100;


        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;


    SELECT COUNT (*) INTO cntr FROM large_culverts;
    
  

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
