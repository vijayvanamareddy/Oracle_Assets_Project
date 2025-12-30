CREATE OR REPLACE PROCEDURE load_projects_on_route
IS
    /**********************************************************************
    05-03-2021 SH Initial Version
               Loads the sections and begin and end location of each project for each primary and alternate route

               This table joins to project_locations by psn and route number
               It joins to the complete_transportation_network via section_id

               Note:  Projects are not always coded to the primary route

04-08-2024 SH Add projects for nodes, cross culverts, traffic signals, and railroad crossings using Projex as Source DOTDW-899
04-17-2024 SH Revised to keep history by year, Add snapshot_year column, delete and re-load current year instead of truncating
05-13-2024 SH Add est_cost since it is used in the analytics model
12-10-2024 SH Add begin_offset, end_offset, workplan_descr, work_status to facilitate the change from project_locations to projects_on_route from obi
    **********************************************************************/



    commit_count   NUMBER (7) := 0;
    cntr           NUMBER (7) := 0;

    g_start_time   DATE := SYSDATE;
    g_owner        VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname      VARCHAR2 (30) := 'LOAD_PROJECTS_ON_ROUTE';
    g_object       VARCHAR2 (30) := 'PROJECTS_ON_ROUTE';
    g_sqlmsg       VARCHAR2 (500) := NULL;

    bsection_id    NUMBER;
    bprimary       VARCHAR2 (1);

    esection_id    NUMBER;
    eprimary       VARCHAR2 (1);
    current_yr     NUMBER;

    CURSOR linear_proj_sections IS
        SELECT pl.psn,
               pl.route_number     project_route_number,
               pl.project_bmp,
               pl.project_emp,
               pl.asset_type,
               pl.est_cost,
               pl.BEGIN_OFFSET,
               pl.END_OFFSET,
               pl.WORK_STATUS,
               pl.WORKPLAN_DESCR,
               c.route_number,
               c.begin_section_mp,
               c.end_section_mp,
               c.section_id,
               c.element_id,
               c.primary
          FROM V_COMPLETE_TRANSP_NETWORK  c
               JOIN project_locations pl ON c.section_id = pl.section_id
         WHERE     pl.ASSET_TYPE IN ('ROAD', 'RAIL', 'TRAIL')
               AND c.SNAPSHOT_YEAR = current_yr;


    CURSOR linear_proj_beg_end_points IS
          SELECT pl.psn,
                 c.route_number,
                 MIN (c.begin_section_mp)     begin_project_mp,
                 MAX (c.end_section_mp)       end_project_mp
            FROM V_COMPLETE_TRANSP_NETWORK c
                 JOIN project_locations pl ON c.section_id = pl.section_id
           WHERE     pl.ASSET_TYPE IN ('ROAD', 'RAIL', 'TRAIL')
                 AND c.SNAPSHOT_YEAR = current_yr
        GROUP BY pl.psn,
                 pl.project_bmp,
                 pl.project_emp,
                 c.route_number;

    CURSOR point_locations IS
        SELECT pl.ASSET_TYPE,
               pl.asset_number,
               pl.route_number    project_route_number,
               pl.section_id,
               c.primary,
               CASE
                   WHEN direction = 1
                   THEN
                       ROUND (begin_element_milepoint + pl.begin_OFFSET, 3)
                   WHEN direction = -1
                   THEN
                       ROUND (end_element_milepoint - pl.begin_OFFSET, 3)
               END                milepoint,
               Pl.PSN,
               pl.est_cost,
               pl.BEGIN_OFFSET,
               pl.END_OFFSET,
               pl.WORK_STATUS,
               pl.WORKPLAN_DESCR,
               c.route_number,
               c.element_id
          FROM V_COMPLETE_TRANSP_NETWORK c, project_locations pl
         WHERE     c.section_id = pl.section_id
               AND pl.asset_type IN ('BRIDGE',
                                     'LARGE_CULVERT',
                                     'CROSS_CULVERT',
                                     'RRX',
                                     'TRAFFIC_SIGNAL',
                                     'NODE')
               AND c.SNAPSHOT_YEAR = current_yr;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE PROJECTS_ON_ROUTE_ERROR_LOG';

    current_yr := F_Get_Snapshot_Year;

    DELETE FROM projects_on_route
          WHERE snapshot_year = current_yr;

    COMMIT;

    FOR p IN linear_proj_sections
    LOOP
        INSERT INTO PROJECTS_ON_ROUTE (ASSET_NUMBER,
                                       ASSET_TYPE,
                                       BEGIN_MP,
                                       BEGIN_OFFSET,
                                       ELEMENT_ID,
                                       END_MP,
                                       END_OFFSET,
                                       EST_COST,
                                       PRIMARY,
                                       PROJECT_ROUTE_NUMBER,
                                       PSN,
                                       ROUTE_NUMBER,
                                       SECTION_ID,
                                       SNAPSHOT_YEAR,
                                       WORK_STATUS,
                                       WORKPLAN_DESCR)
                 VALUES (P.ROUTE_NUMBER,                       -- ASSET NUMBER
                         P.ASSET_TYPE,
                         P.BEGIN_SECTION_MP,
                         p.BEGIN_OFFSET,
                         P.ELEMENT_ID,
                         P.END_SECTION_MP,
                         P.END_OFFSET,
                         P.EST_COST,
                         P.PRIMARY,
                         P.PROJECT_ROUTE_NUMBER,
                         P.PSN,
                         P.ROUTE_NUMBER,
                         P.SECTION_ID,
                         current_yr,
                         P.WORK_STATUS,
                         P.WORKPLAN_DESCR)
                LOG ERRORS INTO PROJECTS_ON_ROUTE_ERROR_LOG
                        ('load_projects_on_route ' || g_start_time)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;



    COMMIT;

    FOR lp IN linear_proj_beg_end_points
    LOOP
        UPDATE projects_on_route
           SET project_bmp = lp.begin_project_mp,
               project_emp = lp.end_project_mp
         WHERE     route_number = lp.route_number
               AND psn = lp.psn
               AND begin_mp >= lp.begin_project_mp
               AND end_mp <= lp.end_project_mp
           LOG ERRORS INTO projects_on_route_error_log
                   (   'projects on route - Update begin/end project mps '
                    || g_start_time)
                   REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;



    COMMIT;


    FOR b IN point_locations
    LOOP
        INSERT INTO PROJECTS_ON_ROUTE (ASSET_NUMBER,
                                       ASSET_TYPE,
                                       BEGIN_MP,
                                       BEGIN_OFFSET,
                                       ELEMENT_ID,
                                       END_MP,
                                       END_OFFSET,
                                       EST_COST,
                                       PRIMARY,
                                       PROJECT_BMP,
                                       PROJECT_EMP,
                                       PROJECT_ROUTE_NUMBER,
                                       PSN,
                                       ROUTE_NUMBER,
                                       SECTION_ID,
                                       SNAPSHOT_YEAR,
                                       WORK_STATUS,
                                       WORKPLAN_DESCR)
                 VALUES (b.asset_number,                       -- ASSET NUMBER
                         b.ASSET_TYPE,
                         b.milepoint,
                         b.begin_offset,
                         b.ELEMENT_ID,
                         b.milepoint,
                         b.end_offset,
                         b.est_cost,
                         b.PRIMARY,
                         b.milepoint,                           -- PROJECT_BMP
                         b.milepoint,                           -- PROJECT_EMP
                         b.PROJECT_ROUTE_NUMBER,
                         b.PSN,
                         b.ROUTE_NUMBER,
                         b.SECTION_ID,
                         current_yr,
                         b.work_status,
                         b.workplan_descr)
                LOG ERRORS INTO PROJECTS_ON_ROUTE_ERROR_LOG
                        ('load_projects_on_route ' || g_start_time)
                        REJECT LIMIT 100;


        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;


    SELECT COUNT (*) INTO cntr FROM PROJECTS_ON_ROUTE;

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
