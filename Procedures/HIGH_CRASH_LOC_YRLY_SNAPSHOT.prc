CREATE OR REPLACE PROCEDURE high_crash_loc_yrly_snapshot
IS
    /**********************************************************************
    This procedure is the yearly snapshot procedure of the high_crash_locations table from CRASH.

    At yearly snapshot time the next year is added
    The source of the data is a table with naming convention of 'HCL_TEMP_2014_2016@CRASH' where the
    years are a 3 year span.  If the format of the source changes, the code to generate the variable
    table_name needs to be modified.

    08-11-17 SH  Initial Version
    08-14-17 SH  Add milepoint on primary route, SECTION_ID, HIGHWAY_ID, ELEMENT_ID (for node crash)
    08-21-17 SH  Add federal_functional_class and federal_functional_class_descr
    08-22-17 SH  Lookup town name and county name from DIM_TOWNS
                 Add in high crash locations for all years in crash.
    08-30-17 SH  Get milepoint on primary route from nodes table for node crashes
    09-28-17 SH Remove high crash locations for prior years in crash based on discussion on highway network changes for old hcls
    12-20-17 SH Remove element_id, offset, highway_id, section_id from node crashes
    06-12-18 SH Load 2017
    08-08-18 SH Replace nodes table with all_nodes, lookup ffc for nodes
    08-09-18 SH Replace all_nodes with nodes after renaming it
    08-18-18 SH Lookup state_urban_rural code for nodes with state urban code of 9 (signalized intersections).
    11-28-18 SH - Modify to use full network
    02-11-19 SH - Modify sections_history to sections to pick up new gis segmented network
    02-14-19 SH - Modify all_routes to routes view
    02-22-19 SH - Run weekly as part of crash_weekly_refresh to update highway network locations
    03-26-19 SH - Moved from dev to test
    04-23-19 SH - Rename columns:  PRIMARY_ROUTE_MP TO PRIMARY_ROUTE_BMP, HIGHWAY_ID TO ELEMENT_WID
                  Add columns for location type = section
                      PRIMARY_ROUTE_EMP, ELEMENT_BEGIN_OFFSET, ELEMENT_END_OFFSET, ELEMENT_LENGTH, BEGIN_NODE_DESCRIPTION, BEGIN_NODE_ID,
                      END_NODE_DESCRIPTION, END_NODE_ID
                  Add columns for node and section crashes
                      REGION, REGION_DESCR, HCL_ID
    05-02-19 SH - Initial version created from load_high_crash_locations
                - Adds new year of high crash locations into the table
                - No longer truncates the high_crash_locations table
    04-06-20 SH - Compute hcl_year rather than hardcode it      
    04-05-21 SH - Snapshot, modify source table to HCL_TEMP_2018_2020@crash 
    05-15-22 SH - Snapshot, modify source table to HCL_TEMP_2019_2021@crash 
    04-11-23 SH - Generate table name so it no longer needs to be modified manually
    **********************************************************************/



    commit_count               NUMBER (7) := 0;
    cntr                       NUMBER (7) := 0;

    g_start_time               DATE := SYSDATE;
    g_owner                    VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                  VARCHAR2 (30) := 'HIGH_CRASH_LOC_YRLY_SNAPSHOT';
    g_object                   VARCHAR2 (20) := 'HIGH_CRASH_LOCATIONS';
    g_sqlmsg                   VARCHAR2 (500) := NULL;

    ele_wid                    NUMBER;
    sect_id                    NUMBER;
    el_id                      NUMBER;
    rte_number                 high_crash_locations.primary_route_number%TYPE;
    cnty_code                  high_crash_locations.county_code%TYPE;
    cnty_name                  high_crash_locations.county_name%TYPE;
    reg_number                 high_crash_locations.region%TYPE;
    reg_name                   high_crash_locations.region_descr%TYPE;
    pri_rte_bmp                high_crash_locations.primary_route_bmp%TYPE;
    pri_rte_emp                high_crash_locations.primary_route_emp%TYPE;
    twn_name                   high_crash_locations.town_name%TYPE;
    ele_length                 high_crash_locations.element_length%TYPE;
    bsection_offset            high_crash_locations.ELEMENT_BEGIN_OFFSET%TYPE;
    esection_offset            high_crash_locations.ELEMENT_END_OFFSET%TYPE;
    tsurb                      high_crash_locations.state_urban_rural%TYPE;
    tstate_urban_rural_descr   high_crash_locations.state_urban_rural_descr%TYPE;
    tffc                       high_crash_locations.federal_functional_class%TYPE;
    tffc_descr                 high_crash_locations.federal_functional_class_descr%TYPE;
    thcl_id                    high_crash_locations.hcl_id%TYPE;
    b_node_id                  high_crash_locations.begin_node_id%TYPE;
    b_node_descr               high_crash_locations.begin_node_description%TYPE;
    e_node_id                  high_crash_locations.end_node_id%TYPE;
    e_node_descr               high_crash_locations.end_node_description%TYPE;

    yr                         NUMBER;
    yr_before  varchar2(4);
    yr_after    varchar2(4);
    table_name VARCHAR2(30);
        va                      high_crash_locations.a_crash_count%TYPE;
    vb                      high_crash_locations.b_crash_count%TYPE;
    vc                      high_crash_locations.c_crash_count%TYPE;
    vcounty_ranking        high_crash_locations.county_ranking%TYPE;
    vprirtecode             high_crash_locations.PRIMARY_ROUTE_NUMBER%TYPE;
    vcrash_count            high_crash_locations.total_crash_count%TYPE;
    vcrash_rate             high_crash_locations.crash_rate%TYPE;
    vcritical_crash_rate    high_crash_locations.critical_crash_rate%TYPE;
    vcritical_rate_factor   high_crash_locations.critical_rate_factor%TYPE;
    vk                      high_crash_locations.k_crash_count%TYPE;
    vlocation               NUMBER;
    vlocation_description   high_crash_locations.LOCATION_DESCRIPTION%TYPE;
    vlocation_type          high_crash_locations.LOCATION_TYPE%TYPE;
    vnode_type              high_crash_locations.node_TYPE%TYPE;
    vnumber_of_a            high_crash_locations.A_INJURY_COUNT%TYPE;
    vnumber_of_b            high_crash_locations.b_INJURY_COUNT%TYPE;
    vnumber_of_c            high_crash_locations.c_INJURY_COUNT%TYPE;
    vnumber_of_k            high_crash_locations.k_INJURY_COUNT%TYPE;
    vpd                     high_crash_locations.pd_only_crash_count%TYPE;
    vpercent_injury         high_crash_locations.percent_injury%TYPE;
    vstatewide_ranking      high_crash_locations.STATEWIDE_RANKING%TYPE;
    vsur                    high_crash_locations.STATE_URBAN_RURAL%TYPE;
    vtown_code              high_crash_locations.TOWN_CODE%TYPE;
    vtown_ranking           high_crash_locations.TOWN_RANKING%TYPE;
    vtravel                 high_crash_locations.HMVM%TYPE;
    vprimary_route_number   high_crash_locations.PRIMARY_ROUTE_NUMBER%TYPE;

    
    TYPE HCL_TYPE IS REF CURSOR;
     HCL HCL_TYPE;

  /*  
    CURSOR hcl
    IS
        SELECT a,
               b,
               c,
               county_ranking,
               crash_count,
               crash_rate,
               critical_crash_rate,
               critical_rate_factor,
               k,
               location,
               location_description,
               location_type,
               node_type,
               number_of_a,
               number_of_b,
               number_of_c,
               number_of_k,
               pd,
               percent_injury,
               statewide_ranking,
               sur,
               town_code,
               town_ranking,
               travel,
               CASE
                   WHEN location_type = 'NODE' THEN n.prirtecode
                   ELSE NULL
               END
                   primary_route_number
          FROM HCL_TEMP_2019_2021@crash  c -- modify when adding next year of high crash locations
               LEFT OUTER JOIN mv_nodes_pri@crash n ON n.node = c.location;

*/

    PROCEDURE Get_town_county_region (twn_code    IN     NUMBER,
                                      twn_name       OUT VARCHAR2,
                                      cnty_name      OUT VARCHAR2,
                                      reg            OUT NUMBER,
                                      reg_descr      OUT VARCHAR2)
    IS
        err   VARCHAR2 (100);
    BEGIN
        SELECT county,
               townname,
               maintenance_region,
               mreg_name
          INTO cnty_name,
               twn_name,
               reg,
               reg_descr
          FROM wh_common.dim_towns t
         WHERE t.towncode = twn_code;
    EXCEPTION
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
                         'PROCEDURE',
                         'Get_town_county_region',
                         'TOWN_CODE',
                         twn_code);
    END;



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

    FUNCTION Get_Surb (nodeid IN NUMBER)
        RETURN NUMBER
    -- Lookup state urban rural code
    IS
        surb   NUMBER;
        err    VARCHAR2 (100);
    BEGIN
        SELECT state_urban_rural
          INTO surb
          FROM nodes n
         WHERE n.node_id = nodeid;

        RETURN surb;
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
                         'FUNCTION',
                         'Get_surb',
                         'NODE ID',
                         nodeid);

            RETURN NULL;
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
            err := 'Offset outside range of element, can"t get section ID';

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


    FUNCTION Get_Route_Number (ele_id IN NUMBER) -- Get the primary_route_number given the element_id
        RETURN VARCHAR2
    IS
        rt_num   VARCHAR2 (7);
        err      VARCHAR2 (100);
    BEGIN
        SELECT primary_route_number
          INTO rt_num
          FROM element_history h
         WHERE h.end_date IS NULL AND h.element_id = ele_id;

        RETURN rt_num;
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
                 VALUES ('HIGH_CRASH_LOCATIONS',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'FUNCTION',
                         'Get_Route_Number',
                         'ELEMENT_ID',
                         ele_id);

            RETURN NULL;
    END;

    PROCEDURE Get_Primary_Rte_mp (loc_type   IN     VARCHAR2,
                                  loc        IN     NUMBER,
                                  prirte     IN     VARCHAR,
                                  bmp           OUT NUMBER,
                                  emp           OUT NUMBER)
    -- Get the milepoints along the primary route_number
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

    PROCEDURE Get_ffc (loc_type    IN     VARCHAR2,
                       loc         IN     NUMBER,
                       ffc            OUT NUMBER,
                       ffc_descr      OUT VARCHAR2)
    IS
        err   VARCHAR2 (100);
    BEGIN
        CASE
            WHEN loc_type = 'NODE'
            THEN
                SELECT federal_functional_class,
                       federal_functional_class_descr
                  INTO ffc, ffc_descr
                  FROM nodes n
                 WHERE n.node_id = loc;
            WHEN loc_type = 'SECTION'
            THEN
                SELECT federal_functional_class,
                       federal_functional_class_descr
                  INTO ffc, ffc_descr
                  FROM sections s
                 WHERE s.section_id = loc;
        END CASE;
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
                         'FUNCTION',
                         'Get_ffc',
                         'SECTION_ID',
                         sect_id);

            ffc := NULL;
            ffc_descr := NULL;
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
    SELECT MAX (hcl_year) INTO yr FROM HIGH_CRASH_LOCATIONS;   -- increment the hcl year  
   
    yr_before := TO_CHAR (YR - 1);
    yr_after := TO_CHAR (YR + 1);
    table_name := 'HCL_TEMP_' || yr_before || '_' || yr_after || '@crash';
    
     yr := yr + 1;
    
      DBMS_OUTPUT.put_line ('Yr: ' || yr || ' Tablename: ' || table_name);

    
OPEN hcl FOR 'SELECT a,
               b,
               c,
               county_ranking,
               crash_count,
               crash_rate,
               critical_crash_rate,
               critical_rate_factor,
               k,
               location,
               location_description,
               location_type,
               node_type,
               number_of_a,
               number_of_b,
               number_of_c,
               number_of_k,
               pd,
               percent_injury,
               statewide_ranking,
               sur,
               town_code,
               town_ranking,
               travel,
               CASE
                   WHEN location_type = ''NODE'' THEN n.prirtecode
                   ELSE NULL
               END
                   primary_route_number FROM ' || table_name || ' c 
               LEFT OUTER JOIN mv_nodes_pri@crash n ON n.node = c.location';

    LOOP
        FETCH hcl
            INTO va,
               vb,
               vc,
               vcounty_ranking,
               vcrash_count,
               vcrash_rate,
               vcritical_crash_rate,
               vcritical_rate_factor,
               vk,
               vlocation,
               vlocation_description,
               vlocation_type,
               vnode_type,
               vnumber_of_a,
               vnumber_of_b,
               vnumber_of_c,
               vnumber_of_k,
               vpd,
               vpercent_injury,
               vstatewide_ranking,
               vsur,
               vtown_code,
               vtown_ranking,
               vtravel,
               vprimary_route_number;
        EXIT WHEN hcl%NOTFOUND;
   
        -- Get the primary route number
        rte_number :=
            CASE
                WHEN vlocation_type = 'NODE'                       -- NODE_ID
                                              THEN vprimary_route_number
                ELSE Get_Route_Number (vlocation) -- Get the route number from the element_id
            END;


        Get_Primary_Rte_mp (vlocation_type,
                            vlocation,
                            rte_number,
                            pri_rte_bmp,
                            pri_rte_emp);

        sect_id := NULL;
        tsurb := vsur;

        IF vlocation_type = 'SECTION' AND vlocation IS NOT NULL
        THEN
            Get_element_wid_len (vlocation, ele_wid, ele_length);

            IF ele_wid IS NOT NULL
            THEN
                Get_section_id_offsets (vlocation,
                                        0,
                                        sect_id,
                                        bsection_offset,
                                        esection_offset); -- don't have the offset for high crash locations
            END IF;
        ELSE                                                     -- node crash
            IF vsur = 9                            -- Signalized Intersection
            THEN
                tsurb := Get_surb (vlocation);
            END IF;

            el_id := NULL;
            ele_wid := NULL;
            ele_length := NULL;
            sect_id := NULL;
            bsection_offset := NULL;
            esection_offset := NULL;
        END IF;

        tstate_urban_rural_descr :=
            highways_description_lookup ('URB_CODE', tsurb, 5);

        cnty_code := SUBSTR (vtown_code, 1, 2); -- first 2 characters of town_code
        Get_town_county_region (vtown_code,
                                twn_name,
                                cnty_name,
                                reg_number,
                                reg_name);

        b_node_id := NULL;
        b_node_descr := NULL;
        e_node_id := NULL;
        e_node_descr := NULL;

        CASE
            WHEN vlocation_type = 'SECTION' AND sect_id IS NOT NULL
            THEN
                Get_ffc (vlocation_type,
                         sect_id,
                         tffc,
                         tffc_descr);
                Get_nodes (sect_id,
                           b_node_id,
                           b_node_descr,
                           e_node_id,
                           e_node_descr);
            WHEN vlocation_type = 'NODE'
            THEN
                Get_ffc (vlocation_type,
                         vlocation,
                         tffc,
                         tffc_descr);
            ELSE
                tffc := NULL;
                tffc_descr := NULL;
        END CASE;

        thcl_id := TO_CHAR (yr) || '-' || TO_CHAR (vlocation);

        INSERT INTO high_crash_locations (a_crash_count,
                                          a_injury_count,
                                          b_crash_count,
                                          b_injury_count,
                                          begin_node_description,
                                          begin_node_id,
                                          county_code,
                                          county_name,
                                          county_ranking,
                                          crash_rate,
                                          critical_crash_rate,
                                          critical_rate_factor,
                                          c_crash_count,
                                          c_injury_count,
                                          element_begin_offset,
                                          element_end_offset,
                                          element_id,
                                          element_length,
                                          end_node_description,
                                          end_node_id,
                                          federal_functional_class,
                                          federal_functional_class_descr,
                                          hcl_id,
                                          hcl_year,
                                          element_wid,
                                          hmvm,
                                          k_crash_count,
                                          k_injury_count,
                                          location_description,
                                          location_type,
                                          mev,
                                          node_id,
                                          node_type,
                                          num_years,
                                          pd_only_crash_count,
                                          percent_injury,
                                          primary_route_bmp,
                                          primary_route_emp,
                                          primary_route_number,
                                          region,
                                          region_descr,
                                          section_id,
                                          statewide_ranking,
                                          state_urban_rural,
                                          state_urban_rural_descr,
                                          total_crash_count,
                                          town_code,
                                          town_name,
                                          town_ranking)
                 VALUES (
                            va,
                            vnumber_of_a,
                            vb,
                            vnumber_of_b,
                            b_node_descr,
                            b_node_id,
                            cnty_code,
                            cnty_name,
                            vcounty_ranking,
                            vcrash_rate,
                            vcritical_crash_rate,
                            vcritical_rate_factor,
                            vc,
                            vnumber_of_c,
                            bsection_offset,
                            esection_offset,
                            CASE
                                WHEN vlocation_type = 'SECTION' -- ELEMENT_ID
                                THEN
                                    vlocation
                                ELSE
                                    el_id
                            END,
                            ele_length,
                            e_node_descr,
                            e_node_id,
                            tffc,
                            tffc_descr,
                            thcl_id,
                            yr,                                --  hcl_year,
                            ele_wid,
                            CASE
                                WHEN vlocation_type = 'SECTION'       -- HMVM
                                THEN
                                    vtravel
                                ELSE
                                    NULL
                            END,
                            vk,
                            vnumber_of_k,
                            vlocation_description,
                            vlocation_type,
                            CASE
                                WHEN vlocation_type = 'NODE'           -- MEV
                                                              THEN vtravel
                                ELSE NULL
                            END,
                            CASE
                                WHEN vlocation_type = 'NODE'       -- NODE_ID
                                                              THEN vlocation
                                ELSE NULL
                            END,
                            vnode_type,
                            3,                                   -- num_years,
                            vpd,
                            vpercent_injury,
                            pri_rte_bmp,
                            pri_rte_emp,
                            rte_number,
                            reg_number,
                            reg_name,
                            sect_id,
                            vstatewide_ranking,
                            tsurb,
                            tstate_urban_rural_descr,
                            vcrash_count,
                            vtown_code,
                            twn_name,
                            vtown_ranking)
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
