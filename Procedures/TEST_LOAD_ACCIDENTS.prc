CREATE OR REPLACE PROCEDURE Test_load_accidents
IS
    /**********************************************************************
    This procedure loads the accidents table from CRASH.

  
    12/15/22 SH Change source of accident_date to crashtime in CAS so the date column contains both date & time to solve issue of crash showing up
                on the next day as time defaults to midnight DOTDW-718
    **********************************************************************/



    commit_count                     NUMBER (7) := 0;
    cntr                             NUMBER (7) := 0;

    g_start_time                     DATE := SYSDATE;
    g_owner                          VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                        VARCHAR2 (30) := 'LOAD_ACCIDENTS';
    g_object                         VARCHAR2 (20) := 'ACCIDENTS';
    g_sqlmsg                         VARCHAR2 (500) := NULL;

    ele_wid                          NUMBER;
    sect_id                          NUMBER;
    el_id                            NUMBER;
    rte_name                         accidents.primary_route_name%TYPE;
    cnty_name                        accidents.county_name%TYPE;
    cnty_code                        accidents.county_code%TYPE;
    twn_name                         accidents.town_name%TYPE;
    regioncode                       accidents.region_code%TYPE;
    regionname                       accidents.region_name%TYPE;
    tinjury_level                    accidents.injury_level%TYPE;
    tinjury_level_code               accidents.injury_level_code%TYPE;
    bsection_offset                  NUMBER;
    esection_offset                  NUMBER;
    ofset                            NUMBER;
    pri_rte_mp                       NUMBER;
    pri_route_num                    accidents.primary_route_number%TYPE;


    tcontrib_circ_env1_descr         accidents.contrib_circ_env1_descr%TYPE;
    tcontrib_circ_env2_descr         accidents.contrib_circ_env2_descr%TYPE;
    tcontrib_circ_road1_descr        accidents.contrib_circ_road1_descr%TYPE;
    tcontrib_circ_road2_descr        accidents.contrib_circ_road2_descr%TYPE;
    tlight_condition_descr           accidents.light_condition_descr%TYPE;
    tloc_first_harmful_event_descr   accidents.loc_first_harmful_event_descr%TYPE;
    treporting_agency_descr          accidents.reporting_agency_descr%TYPE;
    troad_grade_descr                accidents.road_grade_descr%TYPE;
    troad_surf_cond_descr            accidents.road_surf_cond_descr%TYPE;
    tschool_bus_related_descr        accidents.school_bus_related_descr%TYPE;
    ttraffic_control_device_descr    accidents.traffic_control_device_descr%TYPE;
    ttype_of_crash_descr             accidents.type_of_crash_descr%TYPE;
    ttrf_cntrl_dev_oprationl_descr   accidents.Trf_cntrl_dev_oprationl_descr%TYPE;
    ttype_of_location_descr          accidents.type_of_location_descr%TYPE;
    tweather_condition_descr         accidents.weather_condition_descr%TYPE;
    tworkzone_in_or_near_descr       accidents.workzone_in_or_near_descr%TYPE;
    tworkzone_location_descr         accidents.workzone_location_descr%TYPE;
    tworkzone_police_present_descr   accidents.workzone_police_present_descr%TYPE;
    tworkzone_type_descr             accidents.workzone_type_descr%TYPE;
    twzone_workers_present_descr     accidents.workzone_workers_present_descr%TYPE;

    taccident_day_of_week_num        accidents.accident_day_of_week_num%TYPE;
    taccident_day_of_week            accidents.accident_day_of_week%TYPE;
    taccident_year                   accidents.accident_year%TYPE;
    taccident_month_name             accidents.accident_month_name%TYPE;
    taccident_month_num              accidents.accident_month_num%TYPE;
    tfederal_urban_group             accidents.federal_urban_group%TYPE;
    tfederal_urban_group_descr       accidents.federal_urban_group_descr%TYPE;
    tspeed                           accidents.speed_limit%TYPE;
    tsecondary_crash_yn              accidents.secondary_crash_yn%TYPE;
    tfars_yn                         accidents.fars_yn%TYPE;
    TUTC_TIME                        timestamp with time zone;
    
     date1                   DATE := TO_DATE('11/04/2022 00:00:00', 'MM/DD/YYYY HH24:MI:SS');
    date2                   DATE := TO_DATE('11/06/2022 00:00:00', 'MM/DD/YYYY HH24:MI:SS');
    tdate                   DATE;

    CURSOR acc IS
          SELECT c.mdotid                                mdotid,
                 c.crashreportid,
                 crashdate                               accident_date,  -- 12/16/22 changed source from crashdate to crashtime
                 trunc(crashdate) + (crashtime - trunc (crashtime))                                accident_date_time,
                 crashtime,
                 TO_CHAR (crashtime, 'HH24:MI:SS')       accident_time,
                 TO_CHAR (crashtime, 'HH24')             accident_hr,
                 cityortown                              town_code,
                 reportingagency                         reporting_agency,
                 lightcondition                          light_condition,
                 roadgrade                               road_grade,
                 roadsurfacecondition                    road_surf_cond,
                 trafficcontroldevice                    traffic_control_device,
                 trafficcontroldevoperational            trf_cntrl_dev_oprationl,
                 typeofcrash                             type_of_crash,
                 typeoflocation                          type_of_location,
                 weathercondition                        weather_condition,
                 contribcircumstancesenviron1            contrib_circ_env1,
                 contribcircumstancesenviron2            contrib_circ_env2,
                 contributingcircumstancesroad1          contrib_circ_road1,
                 contributingcircumstancesroad2          contrib_circ_road2,
                 locationoffirstharmfulevent             loc_first_harmful_event,
                 --               postedspeedlimit                     speed_limit,            change 8/8/19
                 workzonepolicepresent                   workzone_police_present,
                 workzoneinornear                        workzone_in_or_near,
                 workzoneworkerspresent                  workzone_workers_present,
                 workzonelocation                        workzone_location,
                 workzonetype                            workzone_type,
                 schoolbusrelatedcrash                   school_bus_related,
                 f_getinjurycount (crashreportid, 1)     no_of_k_inj,
                 f_getinjurycount (crashreportid, 2)     no_of_a_inj,
                 f_getinjurycount (crashreportid, 3)     no_of_b_inj,
                 f_getinjurycount (crashreportid, 4)     no_of_c_inj,
                 f_getinjurycount (crashreportid, 5)     no_of_non_inj,
                 f_getinjurycount (crashreportid, 99)    injury_count,
                 mdotoffset_current                      offset,
                 CASE
                     WHEN (mdot_nodecrash_current = 'Y') THEN 'NODE'
                     WHEN (mdot_nodecrash_current = 'N') THEN 'ELEMENT'
                     ELSE NULL
                 END                                     location_type,
                 CASE
                     WHEN (mdotelementid_current IN (0, 1)) THEN NULL
                     ELSE mdotelementid_current
                 END                                     element_id,
                 CASE
                     WHEN (mdot_nodecrash_current = 'Y') THEN mdotnode1_current
                     ELSE NULL
                 END                                     node_id,
                 CASE
                     WHEN (mdot_nodecrash_current = 'Y') THEN mdotnode1
                     ELSE NULL
                 END                                     crash_node_id,
                 --              rtcode                               route_number,
                 reportnumber,
                 rtlat,
                 rtlong,
                 mdotlastmodified,                            -- Added 11-6-19
                 mdotreviewcomment,
                 mdotreviewdate,
                 mdotreviewerid,
                 secondarycrash,
                 fars
            FROM crashreport@CRASH c
           WHERE     mdotreviewed = 1
             AND c.crashdate BETWEEN date1 and date2
                 AND mdotduplicatereport <> 1 -- Include only crashes that have been reviewed and are not duplicates
                 AND     mdotnonhighway <> 1            -- Highway crashes     
        ORDER BY accident_date, mdotid;



    PROCEDURE Get_town_county_region (twn_code    IN     NUMBER,
                                      twn_name       OUT VARCHAR2,
                                      cnty_name      OUT VARCHAR2,
                                      reg_no         OUT NUMBER,
                                      reg_name       OUT VARCHAR2)
    IS
        err   VARCHAR2 (100);
    BEGIN
        SELECT county,
               townname,
               maintenance_region,
               mreg_name
          INTO cnty_name,
               twn_name,
               reg_no,
               reg_name
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
                 VALUES ('accidents',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'FUNCTION',
                         'Get_town_county_region',
                         'TOWN_CODE',
                         twn_code);
    END;

    PROCEDURE Get_Element_Attributes (el_id     IN     NUMBER,
                                      el_wid       OUT NUMBER,
                                      rtenum       OUT VARCHAR,
                                      rtename      OUT VARCHAR)
    IS
        -- Get the element_wid, Primary Route Number and Name from the ELEMENTS view
        err   VARCHAR2 (100);
    BEGIN
        el_wid := NULL;
        rtenum := NULL;
        rtename := NULL;

        SELECT element_wid, primary_route_number, primary_route_name
          INTO el_wid, rtenum, rtename
          FROM elements e
         WHERE e.element_id = el_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            NULL;
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
                 VALUES ('accidents',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'PROCEDURE',
                         'Get_Element_Attributes',
                         'ELEMENT_NUMBER',
                         el_id);
    END;

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
               AND ROUND (offst, 3) >= s.begin_offset
               AND ROUND (offst, 3) <= S.end_offset;

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
                   AND ROUND (offst, 3) >= s.begin_offset
                   AND ROUND (offst, 3) <= s.end_offset;
        END IF;

        IF counter > 1 -- on a section boundary,  the second section is chosen
        THEN
            SELECT s.section_id
              INTO sec_id
              FROM sections s
             WHERE     el_id = s.element_id
                   AND ROUND (offst, 3) >= S.BEGIN_OFFSET
                   AND ROUND (offst, 3) < S.END_OFFSET;
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
                 VALUES ('accidents',
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



    PROCEDURE Get_Section_Attributes (sec_id        IN     NUMBER,
                                      furb             OUT NUMBER,
                                      furb_descr       OUT VARCHAR2,
                                      speed_limit      OUT NUMBER)
    IS
        err   VARCHAR2 (100);
    BEGIN
        SELECT federal_urban_group, federal_urban_group_descr, speed
          INTO furb, furb_descr, speed_limit
          FROM sections s
         WHERE s.section_id = sec_id;
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
                 VALUES ('ACCIDENTS',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'PROCEDURE',
                         'Get_section_attributes',
                         'SECTION_ID',
                         sect_id);

            furb := NULL;
            furb_descr := NULL;
    END;

    PROCEDURE Get_node_attributes (nodeid          IN     NUMBER,
                                   furb               OUT NUMBER,
                                   furb_descr         OUT VARCHAR2,
                                   prim_rte_num       OUT VARCHAR2,
                                   prim_rte_name      OUT VARCHAR2,
                                   mp                 OUT NUMBER)
    IS
        err   VARCHAR2 (100);
    BEGIN
        mp := -1;
        prim_rte_num := NULL;
        prim_rte_name := NULL;
        furb := NULL;
        furb_descr := NULL;

        SELECT federal_urban_group,
               federal_urban_group_descr,
               primary_route_num,
               primary_route_name,
               primary_route_mp
          INTO furb,
               furb_descr,
               prim_rte_num,
               prim_rte_name,
               mp
          FROM nodes n
         WHERE node_id = nodeid;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            NULL;
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
                 VALUES ('ACCIDENTS',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'PROCEDURE',
                         'Get_node_attributes',
                         'NODE_ID',
                         nodeid);
    END;


    FUNCTION Get_Primary_Rte_mp (el_id     IN VARCHAR2,
                                 off_set   IN NUMBER,
                                 prirte    IN VARCHAR) -- Get the milepoint along the priority route_number
        RETURN NUMBER
    IS
        mp    NUMBER := -1;
        bmp   NUMBER;
        emp   NUMBER;
        dir   NUMBER;
        err   VARCHAR2 (100);
    BEGIN
        SELECT begin_element_milepoint, end_element_milepoint, direction
          INTO bmp, emp, dir
          FROM routes r
         WHERE r.element_id = el_id AND r.route_number = prirte;

        IF dir = 1
        THEN
            mp := bmp + off_set;
        ELSE
            mp := emp - off_set;
        END IF;


        RETURN mp;
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
                                         COLUMN_VALUE2,
                                         COLUMN_NAME3,
                                         COLUMN_VALUE3)
                 VALUES ('ACCIDENTS',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'FUNCTION',
                         'Get_Primary_rte_mp',
                         'ELEMENT_ID',
                         el_id,
                         'PRIMARY RTE',
                         prirte);

            RETURN NULL;
    END;
BEGIN
   

    FOR a IN acc
    LOOP
       
      
        -- Get date related columns

        SELECT day_of_week,
               day_of_week_desc,
               dim_time_periods.year,
               dim_time_periods.month,
               month_string
          INTO taccident_day_of_week_num,
               taccident_day_of_week,
               taccident_year,
               taccident_month_num,
               taccident_month_name
          FROM wh_fact.dim_time_periods
         WHERE dim_date = TRUNC (a.accident_date);
         
        
-- DBMS_OUTPUT.PUT_LINE ('mdotid: ' || a.mdotid || ' accident date: ' || a.accident_date || ' accident date time: ' || a.accident_date_time
 --                           || ' taccident_day_of_week_num ' || taccident_day_of_week_num || ' taccident_day_of_week: ' || taccident_day_of_week
 --                           || ' taccident_month_num ' || taccident_month_num || ' taccident_month_name ' || taccident_month_name);
 
 DBMS_OUTPUT.PUT_LINE  ('Accident date: ' || a.accident_date || ' Bad date: ' || to_char(A.crashTIME,'DD-MON-YYYY HH24:MI:SS') || 'date and Time: ' || to_char(A.ACCIDENT_date_TIME,'DD-MON-YYYY HH24:MI:SS') );
      
  TUTC_TIME := SYS_EXTRACT_UTC( A.ACCIDENT_DATE_TIME);
  
  DBMS_OUTPUT.PUT_LINE ('utc TIME : ' || ( to_char(tutc_time,'yyyy-mm-dd"T"HH:MI:SS.FF TZH:TZM'))) ;
 

        end loop;

  EXCEPTION 
WHEN NO_DATA_FOUND THEN 
DBMS_OUTPUT.PUT_LINE(' Procedure Failed' );

WHEN OTHERS THEN
DBMS_OUTPUT.PUT_LINE('UNEXPECTED ERROR: '  || TO_CHAR(SQLCODE) || ' ' || SUBSTR(SQLERRM, 1,60)) ;

END;
/
