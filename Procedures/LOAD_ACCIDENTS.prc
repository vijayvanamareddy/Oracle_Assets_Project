CREATE OR REPLACE PROCEDURE load_accidents
IS
    /**********************************************************************
    This procedure loads the accidents table from CRASH.

    It truncates the table and re-loads it weekly.

    05-02-17 SH  Initial Version
    05-10-17 SH  Modify description lookups
    05-11-17  SH  When an offset is outside the range of an element, can't get the section id, log it into data_exceptions table
    05-15-17 SH Add columns:   RTLAT and RTLONG
    05-23-17 SH Get day of week and Year from warehouse dimension, wh_fact.dim_time_periods
    08-01-17 SH Modified to use local function call to get injury count (f_getinjurycount) based on local materialized view, MV_CRASH_INJURYCOUNT
    08-17-17 SH Remove crash_id, add standard error handling, run weekly in assets_cycle
    08-18-17 SH Add columns from Ed Beckworth spreadsheet: town_code,town_name,postedspeedlimit (as reported by police)
    09-13-17 SH Add fixed_object_struck,fixed_object_struck_descr
    09-19-17 SH Use implicit cursor for lookups Function crash_lookupi
    10-30-17 SH Add column, accident_hour
    10-31-17 SH Add injury_level (indicates the most severe injury in the crash)
    11-17-17 SH Add column injury_level_code (K=1, A=2, B=3, C=4 and PD=5) to facilitate sorting of most severe injury in the crash
    11/20/17 SH Get highway_id, section_id, element_id from nodes_on_route view to fix issues with direction
    11/28/17 SH Set section_id to null for retired elements  (when highway_id not found)
    12/19/17 SH Remove element_id, section_id, highway_id from node crashes.  Look up primary_route_number and primary_route_mp for node from nodes table.  Note this
             may be a change from the primary route number originally entered in the crash record
    01/04/18 SH Add traffic control device operational
    01/23/18 SH Fix injury_level computation
    01/24/18 TAM Removed Fix Object Struct/ code removed 9/6/18 SH
    02/06/18 SH  Set injury_level to 'PD' if there are no K,A,B or C injuries to match what is done in TIDE BIQ
    06/13/18 SH  Look up federal_urban_group and federal_urban_group_descr for node crashes
    06/26/18 SH  Modify Look up of route_name to use wh_common.dim_routes
    09/06/18 SH Add column crash_node_id, which is the actual node where a crash occurred.  It may be the primary node or an associated node.
               The node_id is the primary node where a crash occurred.
    09/07/18 SH  Copy of load_accidents procedure to use the full network
    01/07/19 SH Set indexes unusable prior to loading/rebuild them after loading to improve performance using the MANAGE_INDEXES Package
    07/01/19 SH Return NULL instead of 0 in Get_section_id when section not found to avoid reporting of false exceptions when looking up federal urban rural
    07/29/19 SH Look up the primary route number and name from elements (using the element_id) and nodes (using the node_id) tables instead of taking it from CRASH
    08/08/19 SH Change source of speed to sections table instead of crash report, reorganize code lookups for node vs element crashes in main body
    09/19/19 SH Add column crashreportid, requested by Tom Marcotte
    11/06/19 SH Add columns MDOT_REVIEW_DATE, MDOT_LAST_MODIFIED, MDOT_REVIEWER_ID, MDOT_REVIEW_COMMENT requested by Shawn Hembree
    10/30/20 SH Add WHEN_NO_DATA_FOUND to error handlers for Procedures Get_Element_Attributes, Get_Node_attributes instead of writing to data_exceptions table for
                end dated nodes and elements, when offset is out of range in an element, return -1 in the section_id in Get_section_id
    04/05/21 SH Add secondary_crash column
    06/21/21 SH Round offset to 3 digits in procedure Get_section_id to support METRANS change to thousandth (0.001) of a mile
    09/01/22 SH Add column FARS_YN to indicate if the crash is considered a fars fatility JIRA task dotdw-640
    09/21/22 SH Add Non-highway FARS Crashes
    03/17/23 SH Add 2 new columns ACCIDENT_DATE_TIME and ACCIDENT_DATE_TIME_UTC to solve issue of crash showing up on the next day as time defaults to midnight DOTDW-718
                
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
    taccident_date_time_utc          ACCIDENTS.ACCIDENT_DATE_TIME_UTC%TYPE;

    CURSOR acc IS
          SELECT c.mdotid                                mdotid,
                 c.crashreportid,
                 crashdate                               accident_date,  
                 trunc(crashdate) + (crashtime - trunc (crashtime))       accident_date_time,
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
                 AND mdotduplicatereport <> 1 -- Include only crashes that have been reviewed and are not duplicates
                 AND (       mdotnonhighway <> 1            -- Highway crashes
                         AND (offroadorifw <> 1 OR offroadorifw IS NULL) -- highway crashes do not include offraodorifw set to  1  or null
                         AND (   istotaldamageoverthreshold = 1 -- > Include crashes where the damage is over the threshold or the injury count is > 0
                              OR f_getinjurycount (crashreportid, 99) > 0) 
                      OR (FARS = '1' AND MDOTNONHIGHWAY = 1)) -- Non highway FARS crashes Included 9-21-22
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
    
       FUNCTION Get_UTC_Time ( crashdatetime  IN timestamp)
        RETURN TIMESTAMP WITH TIME ZONE
    IS
        acc_date_time_utc TIMESTAMP(6) WITH TIME ZONE;
        on_dst_boundary EXCEPTION;
        PRAGMA EXCEPTION_INIT(on_dst_boundary,-01878);
    
    BEGIN
          acc_date_time_utc := from_tz(crashdatetime,'US/Eastern');
        RETURN acc_date_time_utc ;
    EXCEPTION
       
        WHEN on_dst_boundary THEN RETURN NULL; 
       
        --    If the time of the crash was on the date/time when day light savings time started or ended, 
        --    an Oracle error, ORA-01878: specified field not found in datetime or interval, is generated.   
        --    Example:  3/11/2007 2:00:00.000000 AM 
    END;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ACCIDENTS';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE ACCIDENTS_ERROR_LOG';

    MANAGE_INDEXES.Mark_Indexes_Unusable ('ACCIDENTS');


    FOR a IN acc
    LOOP
        -- Lookup descriptions

        IF a.contrib_circ_env1 IS NULL
        THEN
            tcontrib_circ_env1_descr := NULL;
        ELSE
            tcontrib_circ_env1_descr :=
                crash_lookupi ('CONTRIB_CIRC_ENV', a.contrib_circ_env1);
        END IF;

        IF a.contrib_circ_env2 IS NULL
        THEN
            tcontrib_circ_env2_descr := NULL;
        ELSE
            tcontrib_circ_env2_descr :=
                crash_lookupi ('CONTRIB_CIRC_ENV', a.contrib_circ_env2);
        END IF;

        IF a.contrib_circ_road1 IS NULL
        THEN
            tcontrib_circ_road1_descr := NULL;
        ELSE
            tcontrib_circ_road1_descr :=
                crash_lookupi ('CONTRIB_CIRC_ROAD', a.contrib_circ_road1);
        END IF;

        IF a.contrib_circ_road2 IS NULL
        THEN
            tcontrib_circ_road2_descr := NULL;
        ELSE
            tcontrib_circ_road2_descr :=
                crash_lookupi ('CONTRIB_CIRC_ROAD', a.contrib_circ_road2);
        END IF;

        IF a.light_condition IS NULL
        THEN
            tlight_condition_descr := NULL;
        ELSE
            tlight_condition_descr :=
                crash_lookupi ('LIGHT_CONDITION', a.light_condition);
        END IF;

        IF a.loc_first_harmful_event IS NULL
        THEN
            tloc_first_harmful_event_descr := NULL;
        ELSE
            tloc_first_harmful_event_descr :=
                crash_lookupi ('LOC_FIRST_HARMFUL_EVENT',
                               a.loc_first_harmful_event);
        END IF;

        IF a.reporting_agency IS NULL
        THEN
            treporting_agency_descr := NULL;
        ELSE
            treporting_agency_descr :=
                crash_lookupi ('REPORTING_AGENCY', a.reporting_agency);
        END IF;

        IF a.road_grade IS NULL
        THEN
            troad_grade_descr := NULL;
        ELSE
            troad_grade_descr := crash_lookupi ('ROAD_GRADE', a.road_grade);
        END IF;

        IF a.road_surf_cond IS NULL
        THEN
            troad_surf_cond_descr := NULL;
        ELSE
            troad_surf_cond_descr :=
                crash_lookupi ('ROAD_SURFACE_CONDITION', a.road_surf_cond);
        END IF;

        IF a.school_bus_related IS NULL
        THEN
            tschool_bus_related_descr := NULL;
        ELSE
            tschool_bus_related_descr :=
                crash_lookupi ('SCHOOL_BUS_RELATED', a.school_bus_related);
        END IF;

        IF a.traffic_control_device IS NULL
        THEN
            ttraffic_control_device_descr := NULL;
        ELSE
            ttraffic_control_device_descr :=
                crash_lookupi ('TRAFFIC_CONTROL_DEVICE',
                               a.traffic_control_device);
        END IF;

        IF a.trf_cntrl_dev_oprationl IS NULL
        THEN
            ttrf_cntrl_dev_oprationl_descr := NULL;
        ELSE
            ttrf_cntrl_dev_oprationl_descr :=
                crash_lookupi ('YES_NO_UNKOWN',
                               TO_CHAR (a.trf_cntrl_dev_oprationl));
        END IF;

        IF a.type_of_crash IS NULL
        THEN
            ttype_of_crash_descr := NULL;
        ELSE
            ttype_of_crash_descr :=
                crash_lookupi ('TYPE_OF_CRASH', a.type_of_crash);
        END IF;

        IF a.type_of_location IS NULL
        THEN
            ttype_of_location_descr := NULL;
        ELSE
            ttype_of_location_descr :=
                crash_lookupi ('TYPE_OF_LOCATION', a.type_of_location);
        END IF;

        IF a.weather_condition IS NULL
        THEN
            tweather_condition_descr := NULL;
        ELSE
            tweather_condition_descr :=
                crash_lookupi ('WEATHER_CONDITION', a.weather_condition);
        END IF;

        IF a.workzone_location IS NULL
        THEN
            tworkzone_location_descr := NULL;
        ELSE
            tworkzone_location_descr :=
                crash_lookupi ('WORKZONE_LOCATION', a.workzone_location);
        END IF;

        IF a.workzone_police_present IS NULL
        THEN
            tworkzone_police_present_descr := NULL;
        ELSE
            tworkzone_police_present_descr :=
                crash_lookupi ('WORKZONE_POLICE_PRESENT',
                               a.workzone_police_present);
        END IF;

        IF a.workzone_type IS NULL
        THEN
            tworkzone_type_descr := NULL;
        ELSE
            tworkzone_type_descr :=
                crash_lookupi ('WORKZONE_TYPE', a.workzone_type);
        END IF;

        IF a.workzone_in_or_near IS NULL OR a.workzone_in_or_near = 0
        THEN
            tworkzone_in_or_near_descr := NULL;
        ELSE
            tworkzone_in_or_near_descr :=
                crash_lookupi ('YES_NO_UNKOWN',
                               TO_CHAR (a.workzone_in_or_near));
        END IF;

        IF    a.workzone_workers_present IS NULL
           OR a.workzone_workers_present = 0
        THEN
            twzone_workers_present_descr := NULL;
        ELSE
            twzone_workers_present_descr :=
                crash_lookupi ('YES_NO_UNKOWN',
                               TO_CHAR (a.workzone_workers_present));
        END IF;


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
         
        

        cnty_code := SUBSTR (a.town_code, 1, 2); -- first 2 characters of town_code
        Get_town_county_region (a.town_code,
                                twn_name,
                                cnty_name,
                                regioncode,
                                regionname);


        pri_route_num := NULL;
        rte_name := NULL;
        pri_rte_mp := NULL;
        ele_wid := NULL;
        sect_id := NULL;
        tfederal_urban_group := NULL;
        tfederal_urban_group_descr := NULL;
        tspeed := NULL;
        el_id := NULL;
        ofset := NULL;


        IF a.LOCATION_TYPE = 'ELEMENT' AND a.element_id IS NOT NULL
        THEN
            Get_Element_Attributes (a.element_id,
                                    ele_wid,
                                    pri_route_num,
                                    rte_name);
            el_id := a.element_id;
            ofset := a.offset;

            IF pri_route_num IS NOT NULL
            THEN
                pri_rte_mp :=
                    Get_Primary_Rte_mp (el_id, ofset, pri_route_num);
            END IF;

            IF ele_wid IS NOT NULL
            THEN
                sect_id := Get_section_id (a.element_id, a.offset);
            END IF;

            IF sect_id <> -1
            THEN
                Get_section_attributes (sect_id,
                                        tfederal_urban_group,
                                        tfederal_urban_group_descr,
                                        tspeed);
            ELSE
                tfederal_urban_group := NULL;
                tfederal_urban_group_descr := NULL;
                tspeed := NULL;
            END IF;
        END IF;                                       -- Location type ELEMENT



        IF a.location_type = 'NODE' AND a.node_id <> 0
        THEN
            Get_node_attributes (a.node_id,
                                 tfederal_urban_group,
                                 tfederal_urban_group_descr,
                                 pri_route_num,
                                 rte_name,
                                 pri_rte_mp);
        END IF;



        tinjury_level :=
            CASE
                WHEN a.no_of_k_inj > 0 THEN 'K'
                WHEN a.NO_OF_A_INJ > 0 THEN 'A'
                WHEN a.NO_OF_B_INJ > 0 THEN 'B'
                WHEN a.NO_OF_C_INJ > 0 THEN 'C'
                WHEN a.NO_OF_B_INJ > 0 THEN 'B'
                WHEN a.NO_OF_NON_INJ > 0 THEN 'PD'
                ELSE 'PD' -- 02/06/18 SH  Set injury_level to 'PD' if there are no K,A,B or C injuries
            END;


        tinjury_level_code :=
            CASE
                WHEN tinjury_level = 'K' THEN 1
                WHEN tinjury_level = 'A' THEN 2
                WHEN tinjury_level = 'B' THEN 3
                WHEN tinjury_level = 'C' THEN 4
                WHEN tinjury_level = 'PD' THEN 5
                ELSE NULL
            END;

        IF a.secondarycrash = 1
        THEN
            tsecondary_crash_yn := 'Y';
        ELSE
            tsecondary_crash_yn := 'N';
        END IF;

        IF a.fars = 1
        THEN
            tfars_yn := 'Y';
        ELSE
            IF a.fars = 0
            THEN
                tfars_yn := 'N';
            ELSE
                tfars_yn := NULL;
            END IF;
        END IF;
        
        taccident_date_time_utc :=  Get_UTC_time(a.accident_date_time);
        
        INSERT INTO ACCIDENTS (accident_date,
                               accident_date_time,
                               accident_date_time_utc,
                               accident_day_of_week,
                               accident_day_of_week_num,
                               accident_hour,
                               accident_month_name,
                               accident_month_num,
                               accident_time,
                               accident_year,
                               contrib_circ_env1,
                               contrib_circ_env1_descr,
                               contrib_circ_env2,
                               contrib_circ_env2_descr,
                               contrib_circ_road1,
                               contrib_circ_road1_descr,
                               contrib_circ_road2,
                               contrib_circ_road2_descr,
                               county_code,
                               county_name,
                               crash_node_id,
                               crashreportid,
                               element_id,
                               element_wid,
                               fars_yn,
                               federal_urban_group,
                               federal_urban_group_descr,
                               injury_count,
                               injury_level,
                               injury_level_code,
                               latitude,
                               light_condition,
                               light_condition_descr,
                               location_type,
                               loc_first_harmful_event,
                               loc_first_harmful_event_descr,
                               longitude,
                               mdotid,
                               mdot_last_modified,
                               mdot_review_comment,
                               mdot_review_date,
                               mdot_reviewer_id,
                               node_id,
                               no_of_a_inj,
                               no_of_b_inj,
                               no_of_c_inj,
                               no_of_k_inj,
                               no_of_non_inj,
                               offset,
                               primary_route_mp,
                               primary_route_name,
                               primary_route_number,
                               region_code,
                               region_name,
                               report_number,
                               reporting_agency,
                               reporting_agency_descr,
                               road_grade,
                               road_grade_descr,
                               road_surf_cond,
                               road_surf_cond_descr,
                               school_bus_related,
                               school_bus_related_descr,
                               secondary_crash_yn,
                               section_id,
                               speed_limit,
                               town_code,
                               town_name,
                               traffic_control_device,
                               traffic_control_device_descr,
                               trf_cntrl_dev_oprationl,
                               trf_cntrl_dev_oprationl_descr,
                               type_of_crash,
                               type_of_crash_descr,
                               type_of_location,
                               type_of_location_descr,
                               weather_condition,
                               weather_condition_descr,
                               workzone_in_or_near,
                               workzone_in_or_near_descr,
                               workzone_location,
                               workzone_location_descr,
                               workzone_police_present,
                               workzone_police_present_descr,
                               workzone_type,
                               workzone_type_descr,
                               workzone_workers_present,
                               workzone_workers_present_descr)
             VALUES (a.accident_date,
                     a.accident_date_time,
                    taccident_date_time_utc,
                     taccident_day_of_week,
                     taccident_day_of_week_num,
                     a.accident_hr,
                     taccident_month_name,
                     taccident_month_num,
                     a.accident_time,
                     taccident_year,
                     a.contrib_circ_env1,
                     tcontrib_circ_env1_descr,
                     a.contrib_circ_env2,
                     tcontrib_circ_env2_descr,
                     a.contrib_circ_road1,
                     tcontrib_circ_road1_descr,
                     a.contrib_circ_road2,
                     tcontrib_circ_road2_descr,
                     cnty_code,
                     cnty_name,
                     a.crash_node_id,
                     a.crashreportid,
                     el_id,
                     ele_wid,
                     tfars_yn,
                     tfederal_urban_group,
                     tfederal_urban_group_descr,
                     a.injury_count,
                     tinjury_level,
                     tinjury_level_code,
                     a.rtlat,
                     a.light_condition,
                     tlight_condition_descr,
                     a.location_type,
                     a.loc_first_harmful_event,
                     tloc_first_harmful_event_descr,
                     a.rtlong,
                     a.mdotid,
                     a.mdotlastmodified,
                     a.mdotreviewcomment,
                     a.mdotreviewdate,
                     a.mdotreviewerid,
                     a.node_id,
                     a.no_of_a_inj,
                     a.no_of_b_inj,
                     a.no_of_c_inj,
                     a.no_of_k_inj,
                     a.no_of_non_inj,
                     ofset,
                     pri_rte_mp,
                     rte_name,
                     pri_route_num,
                     regioncode,
                     regionname,
                     a.reportnumber,
                     SUBSTR (a.reporting_agency, 3, 5),
                     treporting_agency_descr,
                     a.road_grade,
                     troad_grade_descr,
                     a.road_surf_cond,
                     troad_surf_cond_descr,
                     a.school_bus_related,
                     tschool_bus_related_descr,
                     tsecondary_crash_yn,
                     sect_id,
                     tspeed,
                     a.town_code,
                     twn_name,
                     a.traffic_control_device,
                     ttraffic_control_device_descr,
                     a.trf_cntrl_dev_oprationl,
                     ttrf_cntrl_dev_oprationl_descr,
                     a.type_of_crash,
                     ttype_of_crash_descr,
                     a.type_of_location,
                     ttype_of_location_descr,
                     a.weather_condition,
                     tweather_condition_descr,
                     a.workzone_in_or_near,
                     tworkzone_in_or_near_descr,
                     a.workzone_location,
                     tworkzone_location_descr,
                     a.workzone_police_present,
                     tworkzone_police_present_descr,
                     a.workzone_type,
                     tworkzone_type_descr,
                     a.workzone_workers_present,
                     twzone_workers_present_descr)
                LOG ERRORS INTO accidents_error_log
                        ('Load ACCIDENTS ' || SYSDATE)
                        REJECT LIMIT 100;


        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;
    MANAGE_INDEXES.Rebuild_Unusable_Indexes ('ACCIDENTS');

    SELECT COUNT (*) INTO cntr FROM ACCIDENTS;

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
