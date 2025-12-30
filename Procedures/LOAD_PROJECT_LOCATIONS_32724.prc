CREATE OR REPLACE PROCEDURE load_project_locations_32724
IS
    /**********************************************************************
    07-21-2020 SH Initial Version
               Load Location of highway, rail, and trail projects from GIS system - project_locations table

               This table is used by obiee and is joined to the complete_transportation_network via section_id to
               get information about the highway, rail, or trail and to wh_projex tables to get project information
    08-19-2020 SH Add Bridge Projects
    11-12-2020 SH Add columns project_bmp and project_emp (Jerry Casey request)
    02-03-2021 SH Add large culverts
    02-16-2021 SH Add section bmp, emp to get the first and last sections in a project on a route to help determine alternate route begin/end project milepoints
    12-14-2021 SH Add traffic signals
    02-22-2024 SH Add projects for nodes, cross culverts, and railroad crossings using Projex as Source DOTDW-899
    02-27-2024 SH Change source of traffic signals from gis system to projex
    03-27-2024 SH Version that matches prod - before revised to keep history by year, add snapshot_year column
    **********************************************************************/



    commit_count   NUMBER (7) := 0;
    cntr           NUMBER (7) := 0;

    g_start_time   DATE := SYSDATE;
    g_owner        VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname      VARCHAR2 (30) := 'LOAD_PROJECT_LOCATIONS';
    g_object       VARCHAR2 (30) := 'PROJECT_LOCATIONS';
    g_sqlmsg       VARCHAR2 (500) := NULL;
    telement_id    NUMBER;
    tsection_id    NUMBER;
    toffset        NUMBER;
    tbegin_section_mp NUMBER;
    tend_section_mp  NUMBER;


    CURSOR proj_sections
    IS
        SELECT psn,                   -- Road, Rail, Trail
               section_id,
               element_id,
               begin_offset,
               end_offset,
               begin_section_mp,
               end_section_mp,
               est_cost,
               rtcode         as route_number,
               c.seg_type_cde as asset_type,
               c.segment_id   as asset_number,
               workplan_desc,
               work_status,
               c.beg_rlm_nbr,  -- project_bmp
               c.end_rlm_nbr   -- project_emp
          FROM capital_projects_linear@gis c, route_sections rs
         WHERE     c.rtcode = rs.route_number
               AND begin_section_mp >= c.beg_rlm_nbr
               AND end_section_mp <= c.end_rlm_nbr
        UNION
        SELECT psn,                           -- In service bridges
               i.section_id,
               i.element_id_on_structure,
               i.offset       AS begin_offset,
               i.offset       AS end_offset,
               i.milepoint    AS begin_section_mp,
               i.milepoint    AS end_section_mp,
               est_cost,
               rtcode         AS route_number,
               c.seg_type_cde AS asset_type,
               c.segment_id   AS asset_number,
               workplan_desc,
               work_status,
               c.beg_rlm_nbr,
               c.end_rlm_nbr
          FROM capital_projects_point@gis c, ibridges i
         WHERE seg_type_cde = 'BRIDGE' AND c.segment_id = i.bridge_number
        UNION
        SELECT psn,                          -- Archived Bridges
               i.section_id,
               i.element_id_on_structure,
               i.offset       AS begin_offset,
               i.offset       AS end_offset,
                i.milepoint    AS begin_section_mp,
               i.milepoint    AS end_section_mp,
               est_cost,
               rtcode         AS route_number,
               c.seg_type_cde AS asset_type,
               c.segment_id   AS asset_number,
               workplan_desc,
               work_status,
               c.beg_rlm_nbr,
               c.end_rlm_nbr
          FROM capital_projects_point@gis c, archived_bridges i
         WHERE seg_type_cde = 'BRIDGE' AND c.segment_id = i.bridge_number
         UNION
         SELECT psn,                  -- LARGE CULVERTS                  
               l.section_id,
               l.element_id,
               l.offset       AS begin_offset,
               l.offset       AS end_offset,
               l.milepoint    AS begin_section_mp,
               l.milepoint    AS end_section_mp,
               est_cost,
               rtcode         AS route_number,
               c.seg_type_cde AS asset_type,
               c.segment_id   AS asset_number,
               workplan_desc,
               work_status,
               c.beg_rlm_nbr,
               c.end_rlm_nbr
          FROM capital_projects_point@gis c, LARGE_CULVERTS l
         WHERE seg_type_cde = 'LARGE_CULVERT' AND c.segment_id = l.ASSET_SYS_ID
         ;
         
         cursor xx_sections is --  Source is projex
          SELECT c.proj_seq, -- Cross Culverts 
          a.rtcode         as route_number,
               a.asset_type as asset_type,
               a.asset_id   as asset_number,
               a.measure  as milepoint,
                 p.work_plan_desc,
               p.work_status
          from v_gis_project_locations@projprd c, GIS_ASSET_INFO@projprd a, wh_projex.db_model_pm_project p 
         where a.asset_type = 'CROSS_CULVERT' and a.end_dt IS NULL  and  a.asset_id = substr(c.location_name ,4) and c.proj_seq = p.proj_seq
         UNION
        SELECT c.proj_seq,      -- Rail Crossings, Traffic Signals, Nodes    
               a.rtcode         as route_number,
               a.asset_type as asset_type,
               a.asset_id   as asset_number,
               a.measure  as milepoint,
               p.work_plan_desc,
               p.work_status
          from v_gis_project_locations@projprd c, GIS_ASSET_INFO@projprd a, wh_projex.db_model_pm_project p 
         where a.asset_type IN ('RRX', 'TRAFFIC_SIGNAL','NODE')and a.end_dt IS NULL  and  a.asset_id = c.segment_id and c.proj_seq = p.proj_seq;


BEGIN

    EXECUTE IMMEDIATE 'TRUNCATE TABLE PROJECT_LOCATIONS';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE PROJ_LOC_ERROR_LOG';


    FOR ps IN proj_sections
    LOOP
        INSERT INTO PROJECT_LOCATIONS (asset_number,
                                               asset_type,
                                               begin_offset,
                                               begin_section_mp,
                                               element_id,
                                               end_offset,
                                               end_section_mp,
                                               est_cost,
                                               section_id,
                                               project_bmp,
                                               project_emp,
                                               psn,
                                               route_number,
                                               workplan_descr,
                                               work_status)
             VALUES (ps.asset_number,
                     ps.asset_type,
                     ps.begin_offset,
                     ps.begin_section_mp,
                     ps.element_id,
                     ps.end_offset,
                     ps.end_section_mp,
                     ps.est_cost,
                     ps.section_id,
                     ps.beg_rlm_nbr,
                     ps.end_rlm_nbr,
                     ps.psn,
                     ps.route_number,
                     ps.workplan_desc,
                     ps.work_status
                    )
                LOG ERRORS INTO PROJ_LOC_ERROR_LOG
                        ('load_project_locations ' || SYSDATE)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;



    COMMIT;



 FOR x IN xx_sections
    LOOP
       P_GET_ELEMENT_SECTION(x.route_number, x.milepoint, telement_id, toffset, tsection_id,  tbegin_section_mp,
    tend_section_mp );
    /*
       DBMS_OUTPUT.PUT_LINE ('Route Number: ' || x.route_number 
                            || ' Milepoint: ' || x.milepoint ||  ' Element ID: ' || telement_id || ' Section ID: ' || tsection_id
                            || ' BMP: ' || tbegin_section_mp || ' EMP: ' || tend_section_mp);
                            */
         INSERT INTO PROJECT_LOCATIONS (asset_number,
                                               asset_type,
                                               begin_offset,
                                               begin_section_mp,
                                               element_id,
                                               end_offset,
                                               end_section_mp,
                                               est_cost,
                                               section_id,
                                               project_bmp,
                                               project_emp,
                                               psn,
                                               route_number,
                                               workplan_descr,
                                               work_status)
             VALUES (x.asset_number,
                     x.asset_type,
                     toffset,
                     Tbegin_section_mp,
                     telement_id,
                     toffset,
                     tend_section_mp,
                     null, -- ps.est_cost,
                     tsection_id,
                     x.milepoint,
                     x.milepoint,
                     x.proj_seq,
                     x.route_number,
                     x.work_plan_desc,
                     x.work_status
                    )
                LOG ERRORS INTO PROJ_LOC_ERROR_LOG
                        ('load_project_locations ' || SYSDATE)
                        REJECT LIMIT 100;
        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
END LOOP;
COMMIT;
       
    
    SELECT COUNT (*) INTO cntr FROM PROJECT_LOCATIONS;

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
