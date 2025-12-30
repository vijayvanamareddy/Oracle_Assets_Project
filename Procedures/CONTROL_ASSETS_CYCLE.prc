CREATE OR REPLACE PROCEDURE CONTROL_ASSETS_CYCLE 
AS

  /**********************************************************************
   This procedure is the controlling procedure that runs all the WEEKLY refresh procedures
   for the complete network which includes highways, rails, trails, ferry 
   
   Initial Version:  
   
   6/17/2015 PD
   
   Revision History: 
   
   9-21-2015 SH  Added WEEKLY_REFRESH_POST_LOAD to run tests and gather optimizer stats of history tables
   6-21-2016 SH  Add road_section_wkly_refresh for tig segments
   6-22-2016 SH Add ibridges_refresh for insptech bridges
   6-27-2016 SH Remove bridges_refresh for retirement of Pontis
   7-5-2016  SH Remove sections and lanes weekly refresh which have been replaced by tig segments
   8-24-2016 SH Add roadway_lanes_weekly_refresh
   12-6-2016 SH Split ibridges refresh into weekend, weekday procedures, invoke the weekend procedure here
   8-17-2017 SH Add loading crashes 
   4-26-2018 SH Copied control_assets_cycle to run refresh of new network containing rail, ferry, and trail
   5-11-2018 SH Run tests after load - test_all_route_types, test_all_route_sections
                Note to self - move the tests into weekly_refresh_postload when we replace the old highway network
                with the network with highway, rail, trail, and ferry
   08-08-2018 SH Remove load_all_nodes as it is now done in crash_weekly_refresh       
   08-14-2018 SH Add Crash_weekly_refresh (moved from control_assets_cycle)  
   11-20-2018 SH Add    BRIDGES_WEEKEND_REFRESH;  
   12-11-2018 SH Remove bridges_weekend_refresh  
   01-25-2018 SH Modify to use new gis segmentation
                  SECTION_WEEKLY_REFRESH;  -- gis segmentation
                  LOAD_CROSS_SECTIONS;
                  TEST_ALL_NEW_ROUTE_SECTIONS;
   02-08-2019 SH Add test_routes which now tests the complete network  
   02-12-2019 SH Run routes_weekly_refresh, new name for all_routes_weekly_refresh , add test_mileage;   new name for test_route_sections     
   02-22-2019 SH Add weekly_refresh_setup, crash_weekly_refresh,  IBRIDGES_WEEKEND_REFRESH,  WEEKLY_REFRESH_POST_LOAD in preparation for this to replace the original control_assets_cycle
   03-12-2019 SH Refresh mv_complete_network
   03-27-2019 SH Move from dev to test
   04-01-2019 SH Add 'C' parameter to mview_refresh.  Remove gathering optimizer stats after refresh as it is done automatically in 12C
   04-17-2019 SH Change mv_complete_network to a table & view complete_transportation_network, v_complete_network and mv_highway_network to a view, v_highway_network
                 Refresh with procedure, load_complete_network instead of DBMS_MVIEW.refresh
   04-18-2019 SH Load speed zone tables with procedures load_speed_zones and load_dim_speed_zones   
                 Rename procedure control_assets_cycle    
  05-29-2019 SH  Replace load_cross_sections procedure with cross_section_weekly_refresh to implement history of cross_sections  
  06-28-2019 SH  Load town1 and lane miles reports:  load_lane_miles_report and load_town1_prep     
  08-08-2019 SH - Run node_weekly_refresh as part of control_assets_cycle instead of crash_weekly_refresh so it can be run before loading the complete network 
  12-20-2019 SH - Add load_streets procedure in preparation for going to production
  04-22-2020 SH - Add load_street_sections procedure
  09-09-2020 SH - Load project locations:  Procedure load_project_locations
  10-15-2020 SH - Load_speed_zone_details - speed zones using dissolve procedure  
                  Load_sections_staging2 - uses match recognize to reduce number of sections (still in testing)
  10-21-20 SH - Remove old speed zones
  11-30-20 SH - Remove procedures that are not used: load_lane_miles_report and load_town1_prep, load_streets, load_street_sections
  02-02-21 SH - Add load_large_culverts
  02-22-21 SH - Load projects_on_route (alternate routes for project begin/end milepoints)
  09-17-21 SH - Add load_dissolved_lanes
  12-17-21 SH - Add load_traffic_signals
  01-04-22 SH - Refresh mv_dissolved_lrap
  03-15-23 SH - Load year over year changes weekly (LOAD_YR_OVER_YR_CHANGES)
  06-30-23 SH - Load maintenance work for large culverts and bridges
  07-25-24 SH - Refresh MV_DISSOLVED_PUBLIC_ROADS jira dotdw-937
  12-05-24 SH - Load Linear Bridges jira DOTDW-725  
   ***********************************************************************************/
    
   g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
   g_jobname                VARCHAR2 (30) := $$PLSQL_UNIT;
   g_start_time             DATE := sysdate;
   g_object                 VARCHAR2 (20)   := NULL;
   g_sqlmsg                 VARCHAR2(1000)  := NULL;
   v_flat_file_counts_txt   varchar2(4000) := NULL;

   gname varchar2(20);
   sqlerm  varchar2(500) := NULL;
   
BEGIN
     select * into gname from global_name;
 
     WEEKLY_REFRESH_SETUP;
     ELEMENT_WEEKLY_REFRESH;
     SECTION_WEEKLY_REFRESH;  -- gis segmentation
     LOAD_SECTIONS_STAGING_DISSOLVE;  -- in test - uses match recognize to reduce number of sections
     CROSS_SECTION_WEEKLY_REFRESH;
     ROUTES_WEEKLY_REFRESH;
     IBRIDGES_WEEKEND_REFRESH;
     LOAD_LINEAR_BRIDGE_LOCATIONS;
     NODE_WEEKLY_REFRESH;
     LOAD_COMPLETE_NETWORK;
     LOAD_YR_OVER_YR_CHANGES;
     LOAD_LARGE_CULVERTS;
     LOAD_LARGE_CULVERTS_MAINT_WORK;
     LOAD_BRIDGE_MAINT_WORK;
     LOAD_TRAFFIC_SIGNALS;
     LOAD_PROJECT_LOCATIONS;
     LOAD_PROJECTS_ON_ROUTE;
     Load_speed_zone_details;  -- uses new dissolve
     LOAD_DIM_SPEED_ZONES;
     LOAD_DISSOLVED_LANES;
     DBMS_MVIEW.refresh('MV_DISSOLVED_LRAP','C',atomic_refresh => false);
     DBMS_MVIEW.refresh('MV_DISSOLVED_PUBLIC_ROADS','C',atomic_refresh => false);
     CRASH_WEEKLY_REFRESH;   
     WEEKLY_REFRESH_POST_LOAD;

   
      V_flat_file_counts_txt := 'Assets Cycle Completed';
      
      WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (OWNER => G_OWNER, OBJECT_NAME => g_object,
      -- object_cnt => cntr, add_cnt => cntr_added, update_cnt => cntr_updated,
       proc => $$PLSQL_UNIT, start_time => g_start_time);   

      wh_common.pkg_common_utilities.EXIT_AND_REPORT ($$PLSQL_UNIT,'NORMAL',V_flat_file_counts_txt);
      
      exception when others then 
          WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG
            (OWNER => G_OWNER, OBJECT_NAME => g_object, proc => $$PLSQL_UNIT,   STATUS => 'Failed');

          WH_COMMON.PKG_COMMON_UTILITIES.EXIT_AND_REPORT(g_jobname,'FAILURE',$$PLSQL_UNIT||' '||SUBSTR(SQLERRM,1,400));  
          raise_application_error(-20099,
                  'Error in '||$$PLSQL_UNIT||': '||SUBSTR(SQLERRM,1,400));
       
END;
/
