CREATE OR REPLACE PROCEDURE Load_Routes_Staging
IS
    /*********************************************************************************************************
    This procedure loads the routes staging table, which contains the route log miles for the primary and alternate
    routes.

    It is invoked from the Routes_weekly_refresh procedure

    04/07/15 SH Modified to include ramps to avoid gaps in the route and elements not in the datamart
    07/01/15 SH Modified to load all ramps and cuts (ne_gty_group_type = 'RMPM', 'RMPL')
    11/09/16 SH Add logging to wh_common.tb_whse_log, replace DECODE with CASE
    03/26/18 SH Add Ferry, Rail, and Trail Routes
    04/25/18 SH Add route_type
    07/24/18 SH Modify Route_system to match values in dim_routes (ie 'INTERSTATE')
                Add route_group to store metrans values ne_gty_group_type (ie 'RMNI')
    08/02/18 SH Rename highway_id to element_wid
                Look up route system and route type from dim_routes
    02/12/19 SH Rename to routes_history which uses the full network
    03/26/19 SH Add sortord from metrans v_bns_comprtesys   
    04/02/19 SH Add town_code, region, region_descr columns.  Looked up from wh_common            
    **********************************************************************************************************/

    rt_system        routes_history.route_system%TYPE;
    rt_type          routes_history.route_type%TYPE;
    cntr             NUMBER (7) := 0;
    commit_count     NUMBER (7) := 0;
    common_rundate   DATE := SYSDATE;

    CURSOR rte
    IS
        SELECT e.ne_unique
                   route_number,
               e.ne_descr
                   route_name,
               ee.ne_id
                   element_id,
               CASE
                   WHEN m.nm_cardinality = '-1' THEN ee.ne_no_end
                   ELSE ee.ne_no_start
               END
                   begin_node_id,
               m.nm_true
                   begin_mp,
               m.nm_end_true
                   end_mp,
               CASE
                   WHEN m.nm_cardinality = '-1' THEN ee.ne_no_start
                   ELSE ee.ne_no_end
               END
                   end_node_id,
               m.nm_cardinality
                   direction,
               ee.ne_length
                   element_length,
               element_wid,
               m.nm_seq_no
                   cumulative_milepoint_order,
               Develop_town (ee.ne_id)
                   town,
               e.ne_gty_group_type
                   route_group,
                   c.sortord
          FROM nm_elements@metrans  e,
               nm_members@metrans   m,
               nm_elements@metrans  ee,
               elements             h,
               v_bns_comprtesys@metrans c
         WHERE     e.ne_id = m.nm_ne_id_in
               AND m.nm_ne_id_of = ee.ne_id
               AND e.ne_gty_group_type IN ('RNMI',
                                           'RNMS',
                                           'RNMU',
                                           'RCOL',
                                           'RINV',
                                           'RPMS',
                                           'RMPM',
                                           'RMPL',
                                           'RFER',
                                           'RRRT',
                                           'RTRL')
               AND ee.ne_id = h.element_id(+)
               AND ee.ne_id = c.link_id 
               AND e.ne_unique = c.rtcode ;
          


    CURSOR primary_csr
    IS
        SELECT route_number, Element_id
          FROM routes_staging a, v_bns_prirte@metrans vbp
         WHERE route_number = rtcode AND TO_NUMBER (element_id) = ne_id;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ROUTES_STAGING ';

    FOR r IN rte
    LOOP
        P_Get_Route_Type_System (r.route_number, rt_type, rt_system);

        INSERT INTO routes_staging (route_number,
                                    route_name,
                                    element_id,
                                    begin_node_id,
                                    begin_element_milepoint,
                                    end_element_milepoint,
                                    end_node_id,
                                    direction,
                                    element_length,
                                    primary,
                                    element_wid,
                                    cumulative_milepoint_order,
                                    town,
                                    route_group,
                                    route_system,
                                    route_type,
                                    sortord)
             VALUES (r.route_number,
                     r.route_name,
                     r.element_id,
                     r.begin_node_id,
                     r.begin_mp,
                     r.end_mp,
                     r.end_node_id,
                     r.direction,
                     r.element_length,
                     'N',                                           -- primary
                     r.element_wid,
                     r.cumulative_milepoint_order,
                     r.town,
                     r.route_group,
                     rt_system,
                     rt_type,
                     r.sortord )
                LOG ERRORS INTO routes_history_error_log
                        ('Insert Routes Staging ' || SYSDATE)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;


    -- update primary code

    FOR rec IN primary_csr
    LOOP
        UPDATE routes_staging
           SET primary = 'Y'
         WHERE     element_id = rec.element_id
               AND route_number = rec.route_number
           LOG ERRORS INTO routes_history_error_log
                   ('Update Routes Staging Primary ' || SYSDATE)
                   REJECT LIMIT 100;
    END LOOP;

    COMMIT;
    
     -- Look up the town code, county code,  county, region, region_desciption from wh_common.dim_towns

   UPDATE routes_staging r
      SET (r.town_code,
           r.region,
           r.region_descr) =
             (SELECT t.towncode,
                     t.maintenance_region,
                     t.mreg_name
                FROM wh_common.dim_towns t
               WHERE r.town = t.townname)
      LOG ERRORS INTO routes_history_error_log ('Load town code and region in routes_staging ' || SYSDATE)
             REJECT LIMIT 100;

   COMMIT;

    SELECT COUNT (*) INTO cntr FROM routes_staging;

    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
        OWNER         => 'WH_ASSETS',
        OBJECT_NAME   => 'ROUTES_STAGING',
        object_cnt    => cntr,
        add_cnt       => cntr,
        proc          => $$PLSQL_UNIT,
        start_time    => common_rundate);
EXCEPTION
    WHEN OTHERS
    THEN
        wh_common.pkg_common_utilities.update_whse_log (
            'WH_ASSETS',
            $$PLSQL_UNIT,
            NULL,
            NULL,
            NULL,
            NULL,
               'Error during '
            || $$PLSQL_UNIT
            || ' Line:'
            || $$PLSQL_LINE
            || ': '
            || SUBSTR (SQLERRM, 1, 400),
            'Failed');
        wh_common.pkg_common_utilities.exit_and_report (
            $$PLSQL_UNIT,
            'FAILURE',
               'Error during '
            || $$PLSQL_UNIT
            || ': '
            || SUBSTR (SQLERRM, 1, 400));
        RAISE_APPLICATION_ERROR (
            -20030,
            $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
END;
/
