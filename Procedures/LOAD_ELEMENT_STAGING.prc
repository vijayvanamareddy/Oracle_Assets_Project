CREATE OR REPLACE PROCEDURE load_element_staging
IS
   /**********************************************************************
   This procedure loads the element_staging table from MeTrans

   10-14 PD Created procedure from load_highways to load staging table.
        Added trim to begin & end node descr to avoid false mis-match
   3-17-15  SH - Lookup region and region_description from dim_towns rather than from metrans
   7-1-15   SH - Add elements for ramps, cuts, and collector routes (when they are the primary route)
   7-8-15   SH - Exclude distance breaks in the highways table
   3-20-18  SH - Create new procedure from load_highways_staging.  Add in elements from ferry, rail, and trail routes     
   4-23-18  SH - Add route_type from dim_routes      
   7-31-18  SH - Rename highway_id to element_wid (element warehouse_id) as the network contains more than highways   
                 Rename ROUTE_SYSTEM to ROUTE_GROUP
                 Rename ROUTE_SYSTEM_DESCR to ROUTE_SYSTEM
                 Look up route_type and route_system from dim_routes
   5-28-20  SH - Rename column number_of_lanes to number_of_lane_xsections (Tom Marcotte request)
                 The number of lanes can be obtained from the section level column lane_count
               - Add Column GA_TYPE and GA_TYPE_DESCR (Ed Beckworth request)
   **********************************************************************/


   one_way_description        element_history.one_way_descr%TYPE ;
   ramp_description           element_history.ramp_descr%TYPE ; 
   rt_system                  element_history.route_system%TYPE ; 
   rt_type                    element_history.route_type%TYPE ; 
   commit_count               NUMBER (7) := 0;
   cntr                       NUMBER (7) := 0;
   g_start_time               DATE := SYSDATE;
   g_owner                    VARCHAR2 (20) := 'WH_ASSETS';
   g_jobname                  VARCHAR2 (30) := 'LOAD_ELEMENT_STAGING';
   g_object                   VARCHAR2 (20) := 'ELEMENT_STAGING';
   g_sqlmsg                   VARCHAR2 (500) := NULL;
  

   CURSOR ele
   IS
      SELECT ee.ne_id element_id,         
             ee.ne_length element_length,
             ee.ne_name_2 existing,
             ee.ne_name_1 one_way,
             ee.ne_prefix ramp,
             e.ne_sub_type directional_suffix,
             e.ne_gty_group_type route_group,
             ee.ne_no_start begin_node_id,
             TRIM (n.no_descr) begin_node_descr,
             ee.ne_no_end end_node_id,
             TRIM (nn.no_descr) end_node_descr,
             e.ne_descr route_name,
             e.ne_unique route_number,
             l.cnt number_of_lane_xsections,
             ee.ne_sub_type official_miles,
             ee.ne_group factor_group
        FROM nm_elements@metrans e,
             nm_members@metrans m,
             nm_elements@metrans ee,
             nm_nodes_all@metrans n,
             nm_nodes_all@metrans nn,
             v_nm_lane_nw_count@metrans l,
             v_bns_prirte@metrans p
       WHERE     e.ne_id = m.nm_ne_id_in
             AND m.nm_ne_id_of = ee.ne_id
             AND e.ne_gty_group_type IN ('RINV',
                                         'RNMU',
                                         'RNMI',
                                         'RNMS',
                                         'RMPM',
                                         'RMPL',
                                         'RCOL',
                                         'RFER',
                                         'RRRT',
                                         'RTRL')
             AND ee.ne_length > 0          -- eliminate distance breaks
             AND ee.ne_no_start = n.no_node_id
             AND ee.ne_no_end = nn.no_node_id
             AND ee.ne_id = l.ne_id_of(+)
             AND ee.ne_id = p.ne_id
             AND                                       
                e.ne_descr = p.rtname; -- primary route only
 
BEGIN

   EXECUTE IMMEDIATE 'truncate table element_staging';

   FOR h IN ele   
   LOOP
   
   -- Lookup description columns
      one_way_description :=
         wh_assets.highways_description_lookup ('ONE_WAY', h.one_way, 40); 

      ramp_description :=
         wh_assets.highways_description_lookup ('MAINE_RAMPS', h.ramp, 10);

        P_Get_Route_Type_System (h.route_number, rt_type, rt_system);   

      INSERT INTO element_staging (element_id,
                                    element_length,
                                    existing,
                                    one_way,
                                    one_way_descr,
                                    ramp,
                                    ramp_descr,
                                    directional_suffix,
                                    route_group,
                                    route_system,
                                    begin_node_id,
                                    begin_node_description,
                                    end_node_id,
                                    end_node_description,
                                    primary_route_name,
                                    primary_route_number,
                                    number_of_lane_xsections,
                                    official_miles,
                                    route_type,
                                    factor_group)
              VALUES (h.element_id,
                      h.element_length,
                      h.existing,
                      h.one_way,
                      one_way_description,
                      h.ramp,
                      ramp_description,
                      h.directional_suffix,
                      h.route_group,
                      rt_system,
                      h.begin_node_id,
                      h.begin_node_descr,
                      h.end_node_id,
                      h.end_node_descr,
                      h.route_name,
                      h.route_number,
                      h.number_of_lane_xsections,
                      h.official_miles,
                      rt_type,
                      h.factor_group)
              LOG ERRORS INTO element_error_log ('Insert Elements Loading element_staging ' || SYSDATE)
                     REJECT LIMIT UNLIMITED;

      commit_count := commit_count + 1;

      IF commit_count > 10000
      THEN
         COMMIT;
         commit_count := 0;
      END IF;
   END LOOP;

   COMMIT;

   -- Add the Town

   UPDATE element_staging h
      SET town =
             (SELECT ee.ne_descr
                FROM nm_elementS@metrans e,
                     nm_members@metrans m,
                     nm_elements@metrans ee
               WHERE     h.element_id = e.ne_id
                     AND m.nm_ne_id_of = e.ne_id
                     AND m.nm_obj_type IN ('TOWN')
                     AND m.nm_ne_id_in = ee.ne_id)
      LOG ERRORS INTO element_error_log ('Update Town ' || SYSDATE)
             REJECT LIMIT 100;

   COMMIT;


   -- Look up the town code, county code,  county, region, region_desciption from wh_common.dim_towns

   UPDATE element_staging h
      SET (h.town_code,
           h.county_code,
           h.county_name,
           h.region,
           h.region_descr,
           h.ga_type) =
             (SELECT t.towncode,
                     t.county_code,
                     t.county,
                     t.maintenance_region,
                     t.mreg_name,
                     t.ga_type
                FROM wh_common.dim_towns t
               WHERE h.town = t.townname)
      LOG ERRORS INTO element_error_log ('Load element town and county in element_staging ' || SYSDATE)
             REJECT LIMIT 100;
             
             UPDATE element_staging 
              SET GA_TYPE_DESCR  =            
              CASE
               WHEN GA_TYPE = 'C' THEN 'City'
               WHEN GA_TYPE = 'P' THEN 'Plantation'
               WHEN GA_TYPE = 'R' THEN 'Reservation'
               WHEN GA_TYPE = 'T' THEN 'Town'
               WHEN GA_TYPE = 'U' THEN 'Unorganized'
               ELSE NULL
           END
         LOG ERRORS INTO element_error_log ('Update GA_DESCR ' || SYSDATE)
             REJECT LIMIT 100;

   COMMIT;

   
      SELECT COUNT (*) INTO cntr FROM element_staging;

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
