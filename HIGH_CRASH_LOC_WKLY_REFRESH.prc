CREATE OR REPLACE PROCEDURE high_crash_loc_wkly_refresh
IS
    /**********************************************************************
    This procedure is the weekly refresh of the high_crash_locations table from CRASH.
    It is run weekly as part of crash_weekly_refresh to update highway network locations
      (section_ids and element_wids) of most recent year

    08-11-17 SH  Initial Version
    08-14-17 SH  Add milepoint on primary route, SECTION_ID, HIGHWAY_ID, ELEMENT_ID (for node crash)
    08-21-17 SH  Add federal_functional_class and federal_functional_class_descr
    08-22-17 SH  Lookup town name and county name from DIM_TOWNS
                 Add in high crash locations for all years in crash.
    08-30-17 SH  Get milepoint on primary route from nodes table for node crashes
    09-28-17 SH Remove high crash locations for prior years in crash based on discussion on highway network changes for old hcls
    12-20-17 SH Remove element_id, offset, highway_id, section_id from node crashes
    06-12-18 SH Load 2017
    08-08-18 SH lookup ffc for nodes
    08-18-18 SH Lookup state_urban_rural code for nodes with state urban code of 9 (signalized intersections).
    02-22-19 SH - Run weekly as part of crash_weekly_refresh to update highway network locations

    04-23-19 SH - Rename columns:  PRIMARY_ROUTE_MP TO PRIMARY_ROUTE_BMP, HIGHWAY_ID TO ELEMENT_WID
                  Add columns for location type = section
                      PRIMARY_ROUTE_EMP, ELEMENT_BEGIN_OFFSET, ELEMENT_END_OFFSET, ELEMENT_LENGTH, BEGIN_NODE_DESCRIPTION, BEGIN_NODE_ID,
                      END_NODE_DESCRIPTION, END_NODE_ID
                  Add columns for node and section crashes
                      REGION, REGION_DESCR, HCL_ID
    05-02-19 SH - Initial version created from load_high_crash_locations
                - No longer truncates the high_crash_locations table
                - Updates location information (section_ids and element_wids) of most recent year weekly
    09-19-19 SH - Update comments, get current_hcl_year from HIGH_CRASH_LOCATIONS instead of hard coding it
    10-29-20 SH - Set section_id to -1 for end_dated elements, instead of writing to data_exceptions table
    **********************************************************************/



    commit_count      NUMBER (7) := 0;
    cntr              NUMBER (7) := 0;

    g_start_time      DATE := SYSDATE;
    g_owner           VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname         VARCHAR2 (30) := 'HIGH_CRASH_LOC_WKLY_REFRESH';
    g_object          VARCHAR2 (20) := 'HIGH_CRASH_LOCATIONS';
    g_sqlmsg          VARCHAR2 (500) := NULL;

    ele_wid           NUMBER;
    sect_id           NUMBER;



    pri_rte_bmp       high_crash_locations.primary_route_bmp%TYPE;
    pri_rte_emp       high_crash_locations.primary_route_emp%TYPE;

    ele_length        high_crash_locations.element_length%TYPE;
    bsection_offset   high_crash_locations.ELEMENT_BEGIN_OFFSET%TYPE;
    esection_offset   high_crash_locations.ELEMENT_END_OFFSET%TYPE;

    b_node_id         high_crash_locations.begin_node_id%TYPE;
    b_node_descr      high_crash_locations.begin_node_description%TYPE;
    e_node_id         high_crash_locations.end_node_id%TYPE;
    e_node_descr      high_crash_locations.end_node_description%TYPE;
    tlocation         high_crash_locations.location_type%TYPE;

    current_hcl_yr    NUMBER;

    CURSOR hcl IS
        SELECT hcl_id,
               location_type,
               node_id,
               element_id,
               primary_route_number
          FROM high_crash_locations
         WHERE hcl_year = current_hcl_yr;


    PROCEDURE Get_element_wid_len (el_id    IN     NUMBER,
                                   el_wid      OUT NUMBER,
                                   el_len      OUT NUMBER)
    IS                                       -- Get the element_wid and length
        err   VARCHAR2 (100);
    BEGIN
        SELECT element_wid, element_length
          INTO el_wid, el_len
          FROM element_history h
         WHERE h.end_date IS NULL AND h.element_id = el_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            el_wid := -1;
            el_len := -1;
        WHEN OTHERS
        THEN
            err :=
                   'Error num :'
                || TO_CHAR (SQLCODE)
                || ' '
                || SUBSTR (SQLERRM, 1, 70);

            INSERT INTO data_exceptions (table_name,
                                         error_condition,
                                         test_procedure,
                                         test_date,
                                         assessment,
                                         column_name1,
                                         column_value1,
                                         column_name2,
                                         column_value2)
                 VALUES ('HCL',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'PROCEDRE',
                         'Get_Element_wid_len',
                         'ELEMENT_NUMBER',
                         el_id);
    END;


    PROCEDURE Get_section_id_offsets (el_id     IN     NUMBER,
                                      offst     IN     NUMBER,
                                      sec_id       OUT NUMBER,
                                      boffset      OUT NUMBER,
                                      eoffset      OUT NUMBER)
    IS
        -- Gets the section id, begin/end offsets of the element from the sections table
        -- using the element id/  offset from crash
        -- In high crash locations we do not have the offset of the crash so 0 is used making the section the first one in the element
        counter   NUMBER;
        err       VARCHAR2 (100);
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
            err := 'Offset outside range of element, can not get section ID';

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
                 VALUES ('HCL',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'PROCEDURE',
                         'Get_section_id_offsets',
                         'ELEMENT_ID',
                         EL_ID,
                         'OFFSET',
                         offst);
        END IF;

        IF counter = 1                            -- not on a section boundary
        THEN
            SELECT s.section_id, s.begin_offset, s.end_offset
              INTO sec_id, boffset, eoffset
              FROM sections s
             WHERE     el_id = s.element_id
                   AND ROUND (offst, 2) >= s.begin_offset
                   AND ROUND (offst, 2) <= s.end_offset;
        END IF;

        -- The following case should never occur since we pass in the offset of 0 for a high crash location
        -- but leaving the code in place in case the offset is ever tracked for a high crash location as it is for crash
        IF counter > 1 -- on a section boundary,  the second section is chosen
        THEN
            SELECT s.section_id, s.begin_offset, s.end_offset
              INTO sec_id, boffset, eoffset
              FROM sections s
             WHERE     el_id = s.element_id
                   AND ROUND (offst, 2) >= S.BEGIN_OFFSET
                   AND ROUND (offst, 2) < S.END_OFFSET;
        END IF;
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
                 VALUES ('HCL',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'PROCEDURE',
                         'Get_section_id_offsets',
                         'ELEMENT_ID',
                         EL_ID,
                         'OFFSET',
                         offst);
    END;



    PROCEDURE Get_Primary_Rte_mp (loc_type   IN     VARCHAR2,
                                  loc        IN     NUMBER,
                                  prirte     IN     VARCHAR,
                                  bmp           OUT NUMBER,
                                  emp           OUT NUMBER)
    -- Get the milepoints along the priority route_number
    IS
        err   VARCHAR2 (100);
    BEGIN
        CASE
            WHEN loc_type = 'NODE'                                  -- NODE_ID
            THEN
                SELECT primary_route_mp
                  INTO bmp
                  FROM nodes n
                 WHERE n.node_id = loc;

                emp := NULL;
            WHEN loc_type = 'SECTION'
            THEN
                SELECT begin_element_milepoint, end_element_milepoint
                  INTO bmp, emp
                  FROM routes r
                 WHERE r.element_id = loc AND r.route_number = prirte;
        END CASE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            bmp := -1;
            emp := -1;
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
                                         COLUMN_VALUE3,
                                         COLUMN_NAME4,
                                         COLUMN_VALUE4)
                 VALUES ('HIGH_CRASH_LOCATIONS',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'FUNCTION',
                         'Get_Primary_rte_mps',
                         'LOCATION_TYPE',
                         loc_type,
                         'LOCATION',
                         loc,
                         'PRIMARY RTE',
                         prirte);

            bmp := -1;
            emp := -1;
    END;



    PROCEDURE Get_nodes (sec_id        IN     VARCHAR,
                         bnode_id         OUT NUMBER,
                         bnode_descr      OUT VARCHAR,
                         enode_id         OUT NUMBER,
                         enode_descr      OUT VARCHAR2)
    IS
        err   VARCHAR2 (100);
    BEGIN
        SELECT begin_node_description,
               begin_node_id,
               end_node_description,
               end_node_id
          INTO bnode_descr,
               bnode_id,
               enode_descr,
               enode_id
          FROM route_sections rs
         WHERE rs.section_id = sec_id AND primary = 'Y';
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
                                         COLUMN_VALUE2)
                 VALUES ('HIGH_CRASH_LOCATIONS',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'PROCEDURE',
                         'Get_nodes',
                         'SECTION_ID',
                         sec_id);

            bnode_id := NULL;
            bnode_descr := NULL;
            enode_id := NULL;
            enode_descr := NULL;
    END;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE HCL_ERROR_LOG';

    SELECT MAX (hcl_year) INTO current_hcl_yr FROM HIGH_CRASH_LOCATIONS;

    FOR h IN hcl
    LOOP
        IF h.location_type = 'NODE'
        THEN
            tlocation := h.node_id;
        ELSE
            tlocation := h.element_id;
        END IF;

        Get_Primary_Rte_mp (h.location_type,
                            tlocation,
                            h.primary_route_number,
                            pri_rte_bmp,
                            pri_rte_emp);

        sect_id := NULL;

        IF h.location_type = 'SECTION' AND h.element_id IS NOT NULL
        THEN
            Get_element_wid_len (h.element_id, ele_wid, ele_length);

            IF ele_wid <> -1  -- do we have the element on the current network
            THEN
                Get_section_id_offsets (h.element_id,
                                        0, -- don't have the offset for high crash locations so use 0
                                        sect_id,
                                        bsection_offset,
                                        esection_offset);
            ELSE
                sect_id := -1;
            END IF;
        ELSE                                                     -- node crash
            ele_wid := NULL;
            ele_length := NULL;
            sect_id := NULL;
            bsection_offset := NULL;
            esection_offset := NULL;
        END IF;


        b_node_id := NULL;
        b_node_descr := NULL;
        e_node_id := NULL;
        e_node_descr := NULL;

        IF h.location_type = 'SECTION' AND sect_id <> -1
        THEN
            Get_nodes (sect_id,
                       b_node_id,
                       b_node_descr,
                       e_node_id,
                       e_node_descr);
        END IF;



        UPDATE high_crash_locations
           SET begin_node_description = b_node_descr,
               begin_node_id = b_node_id,
               element_begin_offset = bsection_offset,
               element_end_offset = esection_offset,
               element_length = ele_length,
               element_wid = ele_wid,
               end_node_description = e_node_descr,
               end_node_id = e_node_id,
               primary_route_bmp = pri_rte_bmp,
               primary_route_emp = pri_rte_emp,
               section_id = sect_id
         WHERE hcl_id = h.hcl_id
           LOG ERRORS INTO hcl_error_log
                   ('Load High Crash Locations ' || SYSDATE)
                   REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;

    SELECT COUNT (*) INTO cntr FROM HIGH_CRASH_LOCATIONS;

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
