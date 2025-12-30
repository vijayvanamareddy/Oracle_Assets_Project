CREATE OR REPLACE PROCEDURE ibridges_daily_refresh (
    cntr_threshold           IN NUMBER := 5000,
    staging_already_loaded   IN VARCHAR2 := 'N')
IS
    /**********************************************************************
    This procedure loads the ibridge_staging table & compares it to the ibridges table
    for the daily refresh.  New bridges are added.  Old bridges are 'RETIRED'.
    Changed bridges cause the current bridge row to be updated with the new values.

    It is run after the bridge data has been exported from Inspect Tech.


    2-26-2015 SH - Modified original update_bridges procedure to overwrite current bridge rows rather than create new row
    3-3-2015  SH - Added logging of changes to BRIDGES_CHANGE_TABLE
    3-5-2015  SH - Added a dbms_scheduler job to run weekly Saturday mornings
    3-11-2015 SH - Modified to update roads associated with bridge, bridge_roads_weekly_refresh process
    3-12-2015 SH - Added check of bridges_error_log
    3-23-2015 SH - Truncate error log prior to loading staging table
    7-7-2015  SH - Change bridge_indicator to 'S630 - 0' when a bridge is retired
    7-28-2015 SH - Eliminate running procedure bridge_location_correction.  Logic has been incorporated into
                   procedure, load_bridges_from_metrans
    7-30-2015 SH - Add BRIDGE_NAME to update
    8-31-2015 SH - Increase the threshold of changes, so when scores are updated for all bridges, will go through
    9-15-2015 SH - Added column route_type_on_structure to bridges table, added code to refresh it
    6-13-2016 SH - Initial version, copy from bridges_weekly_refresh for Inspect Tech bridges
    Compares all columns with the exception of bridge_id and control columns
    6-17-2016 SH - Implemented daily refresh for Inspect Tech data, weekly refresh for location data coming from METrans.
                   Rename procedure to ibridges_refresh
    6-21-2016 SH - Added standard error handling, add to assets_cycle for weekly refresh, run as scheduled job for daily refresh
    6-23-2016 SH - Add columns for JP  min_lat_under_clear_left,
                                       min_lat_under_clear_right
    6-28-2016 SH - Add columns co_owner, co_maintainer for dim_bridges (P. Devlin),
                   userbrdg_owner, userbrdg_mainter for JP along with their descriptions
    7-26-2016 SH - - Add additional columns from Cindy Owings - CLEAR_SPAN_LENGTH, DECK_PROTECTION_CODE,
                   DECK_PROTECTION_DESCR, MAIN_SPAN_NUMBER, MINOR_SPAN_CODE_DESCR (subcategory), NEIGHBOR_STATE_CODE_DESCR
    8/10/2016 SH -   Add new columns from Cindy Owings - BRIDGE_POSTING, BRIDGE_POSTING_DESCR,
                     BORDER_BRIDGE_NUMBER,BORDER_BRIDGE_PERCENT_RESP,
                 CURB_SIDEWALK_WIDTH_LEFT, CURB_SIDEWALK_WIDTH_RIGHT,FEDERAL_LAND_HWY, FEDERAL_LAND_HWY_DESCR,
                 HISTORICAL_SIGNIFICANCE, HISTORICAL_SIGNIFICANCE_DESCR, MIN_NAVCLR_LIFT_BRDG, NAVIGATION_CONTROL, NAVIGATION_CONTROL_DESCR,
                 ON_BASE_HIGHWAY_NETWORK, ON_BASE_HIGHWAY_NETWORK_DESCR, PARALLEL_STRUCTURE_DESIG, PARALLEL_STRUCTURE_DESIG_DESCR,
                 STATUS, STATUS_DESCR, TEMP_STUCTURE_DESIG, TEMP_STRUCTURE_DESIG_DESCR
   8-26-2016 SH - Add new columns requested by Cindy Owings - asset_type, invrte_adt, invrte_adt_truck_percent, invrte_adt_yr,  invrte_dirsuffix,invrte_dirsuffix_descr, invrte_functionclass,
                  invrte_functionclass_descr,invrte_on_nhs, invrte_on_nhs_descr,  invrte_lrs_rtenum,  invrte_lrs_subrtenum,  invrte_rectype,invrte_rtenum,  invrte_on_strahnet,invrte_on_strahnet_descr,
                  invrte_on_trucknet, invrte_on _trucknet_descr, number_lanes_under
   9-7-16 SH - Add columns from special bridge_inspections   FC_INSPECTION_REQUIRED, FC_INSPECTION_FREQUENCY, FC_LAST_INSPECTION
                                                              SI_INSPECTION_REQUIRED, SI_INSPECTION_FREQUENCY, SI_LAST_INSPECTION
                                                              UW_INSPECTION_REQUIRED, UW_INSPECTION_FREQUENCY, UW_LAST_INSPECTION
               - Replace offset from metrans with milepoint (on primary route) from Inspectech (Cindy Owings request)
               - Run the procedures to load inspections and update the most recent approved inspection date as part of the refresh:
                 load_bridge_inspections; load_ibridge_inspection_date;
    10-13-16 SH - Add Posting data from the load-rating form and 5 axle cranes, 5 axle cranes with dolly POSTED, POSTED_WEIGHT_TONS, POSTED_1_TRUCK,
                  POSTED_4_AXLE, POSTED_SPACING, POSTED_5AXLE_CRANE, POSTED_5AXLE_CRANE_DOLLY
    11-7-2016 SH - Add refresh of element inspection data, run load_element_inspections procedure
                 - Check ELEMENT_INSPECTION_ERROR_LOG and BRIDGE_INSPECTIONS_ERROR_LOG for errors
    11-16-2016 SH - Fix counters added, updated, inserted for logging with messaes to make each more intuitive
    11-21-2016 SH - Add columns from Overlimit Form describing Vertical Clearance  OL_NORTH_RIGHT_RAMP_FT, OL_NORTH_RIGHT_RAMP_IN, OL_PERMIT_SOUTH_FT, OL_PERMIT_SOUTH_IN
                  OL_PERMIT_NORTH_FT, OL_PERMIT_NORTH_IN (JP Request)
    12-5-2016 SH - split into ibridges_daily_refresh
                   Remove comparison of columns from metrans which are only updated on the weekend:
                   -    Element_id_on_structure,  section_id,  begin_section_offset, end_section_offset, route_type_on_structure, Highway_id_on_structure,
                      primary_route_number, primary_route_name, priority

    12-9-16 SH - add posting and ratings columns that can be updated via a from independent of an inspection
        APP_GUARDRAIL_END_RATING,  APP_GUARDRAIL_END_RATING_DESCR, APP_GUARDRAIL_RATING, APP_GUARDRAIL_RATING_DESCR, APP_ROAD_ALIGN_RATING,
        APP_ROAD_ALIGN_RATING_DESCR, DECK_GEOMETRY_RATING, DECK_GEOMETRY_RATING_DESCR, PIER_PROTECTION_RATING, PIER_PROTECTION_RATING_DESCR,
        STRUCTURAL_EVALUATION, STRUCTURAL_EVALUATION_DESCR,STRUCTURE_OPEN, STRUCTURE_OPEN_DESCR, UNDERCLEARANCE_RATING, UNDERCLEARANCE_RATING_DESCR
    12-13-2016 SH - Remove update of town columns from daily refresh to maintain order of towns that have been switched on the weekends.  Keep the town columns in the cursor and insert
                    so they will be in new bridges added.
    12-20-16 SH -  Add columns ASSET_STATUS, ASSET_STATUS_DESCR from InspecTech to indicate if a bridge has been archived or is in-service
    12-21-16 SH - Add column INSPECTION_FREQUENCY
    1-4-17   SH -  Add execute load_bridge_program_history , check error log
    02-02-16 SH - Add column ABUT_TO_ABUT_DETOUR (Chester Kolota request)
    02-17-17 SH - Add the metrans offset back in.  Needed to calculate the location of the bridge on primary/alternate routes - Ed Beckwith request
                  New column named milepoint will refer to the milepoint on the primary route and come from InspectTech
                  offset will refer to the offset of the bridge on the element and come from METrans
                  Change offset to milepoint in this procedure.  Offset gets refreshed on the weekend.  Milepoint gets refreshed daily.
    02-24-17  SH - Fixed problem with insert statement, columns out of order
    03-17-17 SH - Add new columns from Over Limit from
                 Jim Foster request
                 OL_PERMIT_LEFT_RAMP_FT, OL_PERMIT_LEFT_RAMP_IN,OL_PERMIT_OTHER_FT,
                 OL_PERMIT_OTHER_IN, OL_PERMIT_PORTAL_NORTH_FT, OL_PERMIT_PORTAL_NORTH_IN,
                 OL_PERMIT_PORTAL_SOUTH_FT, OL_PERMIT_PORTAL_SOUTH_IN,
                 OL_PERMIT_RIGHT_RAMP_FT, OL_PERMIT_RIGHT_RAMP_IN

    04-12-17 SH - Add new columns:  last_element_inspection_date, last_routine_inspection_date
                - Execute the procedure, load_workplan_review, check error log
   04-24-17 SH - Add new columns:  most recent field_review_date and field_review_status
                 - load_ibridge_inspection_date after load_workplan_review to pick up latest review;
                 - Log errors written by Oracle to error log in data exceptions table rather than aborting refresh process
   5/15/17  SH  Add the most recent inspection of anytype, column: last_inspection_anytype
             The column inspection_date is NBI 90 (last routine inspection); the source being currentvalues in InspectTech (change today)
             The column last_routine_inspection is derived from looking at the actual inspections (no change from 4/11/17)
    5/23/17  SH  Invoke the procedure,  monitor_routine_inspections to write inconsistencies with routine inspection dates to the warehouse alert log
    06-06-17 SH  Rearrange order procedures invoked to fix timing problem
                 do not compare columns that get updated after the refresh:  inspection_type, inspection_type_descr, last_routine_inspection_date, last_element_inspection_date,
                 field_review_date, field_review_status
    06-08-17 SH  Add procedure UPDATE_RAILWAY_BRIDGES to set ASSET_TYPE of the bridges that are both highway_bridges and railway_bridges
                 in InspectTech to 'RAILWAY BRIDGES'.
    08-29-17 SH  Invoke rail_bridges_daily_refresh to refresh attributes unique to rail bridges
    05-01-18 SH  Add new columns:  PARENT_ASSET, year_last_painted,year_ws_replaced - Chester Kolota request
    05-03-18 SH  Invoke load_bridge_repairs - Chester Kolota request
    05-24-2018 SH Invoke  monitor_bridge_changes Send an alert report when the following changes are made in InspectTech.
                 a. New Bridge is Added,
                 b. Bridge is Archived, (asset_status set to 0)
                 c. Change in (x,y) location (latitude or longitude)
                 Devon Witherell, GIS Coordinator, also goes to Jim Saban
    08-21-18 SH  Remove comparison of towns, counties, and placecode where a bridge spans multiple towns to eliminate reporting of false updates,
                 This will only be done on the weekends
    08-28-18 SH  Add columns OL_NORTH_MAIN_POSTED, OL_NORTH_OTHER_POSTED, OL_NORTH_RAMP_POSTED, OL_PORTAL_NORTH_POSTED,
                             OL_PORTAL_SOUTH_POSTED, OL_SOUTH_MAIN_POSTED, OL_SOUTH_OTHER_POSTED, OL_SOUTH_RAMP_POSTED
    11-25-18 SH Change references of ibridges to ibridges_history WHERE end_date is NULL to facilitate change to new bridge selection criteria
    10-25-19 SH Fix problem with end_date and date_modified on retired bridges.  Set it to start_time (which is sysdate) not start_date (which is the column name in the row)
    11-13-19 SH Add proposed bridges and archived bridges
    12-03-19 SH Add columns related to underclearances: MIN_VERT_UNDER_REF_FEATURE, MIN_VERT_UNDER_REF_FEATURE_DESCR (NBI54A) requested by Jon Prendergast
    12-20-19 SH Remove running load_proposed_bridges,  they are now part of ibridges_history and extracted with the in-status bridges.  ibridges is a view of just
                in-status bridges, proposed_bridges is a view of proposed bridges
    03-09-20 SH Add columns from ext_ol2 (more overlimit columns)     LR_POSTED_DATE, OL_NORTH_MAIN_POSTED_FT,OL_NORTH_MAIN_POSTED_IN,   OL_NORTH_OTHER_POSTED_FT,
                   OL_NORTH_OTHER_POSTED_IN,OL_NORTH_RAMP_POSTED_FT,OL_NORTH_RAMP_POSTED_IN,OL_PORTAL_NORTH_POSTED_FT,
                   OL_PORTAL_NORTH_POSTED_IN,OL_PORTAL_SOUTH_POSTED_FT,OL_PORTAL_SOUTH_POSTED_IN,OL_SOUTH_MAIN_POSTED_FT,
                   OL_SOUTH_MAIN_POSTED_IN,OL_SOUTH_OTHER_POSTED_FT,OL_SOUTH_OTHER_POSTED_IN,OL_SOUTH_RAMP_POSTED_FT,OL_SOUTH_RAMP_POSTED_IN
    03-10-20 SH Add bridge pointer columns  MTRNS_ASSETNO_LEFT_RAMP,MTRNS_ASSETNO_N_OR_E,MTRNS_ASSETNO_OTHER,MTRNS_ASSETNO_PORTAL_N_OR_E,MTRNS_ASSETNO_PORTAL_S_OR_W,
                  MTRNS_ASSETNO_RIGHT_RAMP,MTRNS_ASSETNO_S_OR_W
    10-07-20 SH Add Refresh of Retaining Walls ( load_retaining_walls)
    04-26-21 SH Add check_bridge_extract procedure to check the success of the assetwise extract
    03-31-22 SH Add check for errors in RETAINING_WALLS_ERROR_LOG 
    01-26-23 SH Add new columns LR_EV2_RATING, LR_EV3_RATING (JIRA DOTDW-758)
    04-05-23 SH Stop running update_railway_bridges - cleanup, as we are now extracting the rail version of duplicate bridges (JIRA DOTDW-714)
    **********************************************************************/
    CURSOR bridge_changes
    IS
        SELECT bridge_number,
               bridge_name,
               abut_to_abut_detour,
               app_guardrail_end_rating,
               app_guardrail_end_rating_descr,
               app_guardrail_rating,
               app_guardrail_rating_descr,
               app_road_align_rating,
               app_road_align_rating_descr,
               approach_roadway_width,
               approach_span_design,
               approach_span_design_descr,
               approach_span_material,
               approach_span_material_descr,
               approach_span_number,
               asset_status,
               asset_status_descr,
               asset_type,
               border_bridge_number,
               border_bridge_percent_resp,
               bridge_condition_score,
               bridge_group,
               bridge_indicator,
               bridge_length,
               bridge_median,
               bridge_median_descr,
               bridge_on_off_system,
               bridge_on_off_system_descr,
               bridge_posting,
               bridge_posting_descr,
               bridge_posting_score,
               bridge_reliability_score,
               channel_rating,
               channel_rating_descr,
               clear_span_length,
               co_maintainer,
               co_maintainer_descr,
               co_owner,
               co_owner_descr,
               culvert_rating,
               culvert_rating_descr,
               curb_sidewalk_width_left,
               curb_sidewalk_width_right,
               year_last_painted,
               year_ws_replaced,
               date_needed,
               deck_area,
               deck_geometry_rating,
               deck_geometry_rating_descr,
               deck_membrane_type,
               deck_membrane_type_descr,
               deck_protection_code,
               deck_protection_descr,
               deck_rating,
               deck_rating_descr,
               deck_structure_type,
               deck_structure_type_descr,
               deck_surface_type,
               deck_surface_type_descr,
               design_load,
               design_load_descr,
               detour_length,
               fc_inspection_required,
               fc_inspection_frequency,
               fc_last_inspection,
               feature_on_structure,
               feature_under_structure,
               federal_land_hwy,
               federal_land_hwy_descr,
               federal_sufficiency_rating,
               fips_region,
               fips_region_descr,
               fips_state_code,
               fips_state_code_desc,
               funding_eligibility,
               geographic_region,
               geographic_region_descr,
               historical_significance,
               historical_significance_descr,
               horizontal_clearance,
               inspection_date,
               inspection_frequency,
               inventory_rating,
               inventory_rating_type,
               inventory_rating_type_descr,
               invrte_adt,
               invrte_adt_truck_percent,
               invrte_adt_yr,
               invrte_dirsuffix,
               invrte_dirsuffix_descr,
               invrte_functionclass,
               invrte_functionclass_descr,
               invrte_on_nhs,
               invrte_on_nhs_descr,
               invrte_lrs_rtenum,
               invrte_lrs_subrtenum,
               invrte_rectype,
               invrte_rtenum,
               invrte_on_strahnet,
               invrte_on_strahnet_descr,
               invrte_on_trucknet,
               invrte_on_trucknet_descr,
               kind_of_highway_on,
               kind_of_highway_on_descr,
               latitude,
               length_max_span,
               level_of_service_on,
               level_of_service_on_descr,
               location_description,
               longitude, 
               lr_ev2_rating, 
               lr_ev3_rating,
               maintainer,
               maintainer_descr,
               maintenance_region,
               maintenance_region_descr,
               main_span_design,
               main_span_design_descr,
               main_span_material,
               main_span_material_descr,
               main_span_number,
               milepoint,
               minor_span_code_descr,
               min_lat_under_clear_left,
               min_lat_under_clear_right,
               min_navclr_lift_brdg,
               min_vertical_clearance_on,
               min_vert_under_clearance,
               min_vert_under_ref_feature,
               min_vert_under_ref_feature_descr,
               MTRNS_ASSETNO_LEFT_RAMP,
               MTRNS_ASSETNO_N_OR_E,
               MTRNS_ASSETNO_OTHER,
               MTRNS_ASSETNO_PORTAL_N_OR_E,
               MTRNS_ASSETNO_PORTAL_S_OR_W,
               MTRNS_ASSETNO_RIGHT_RAMP,
               MTRNS_ASSETNO_S_OR_W,
               navigation_control,
               navigation_control_descr,
               navigation_horizontal,
               navigation_vertical,
               nbis_bridge_length,
               nbis_inspection_done,
               need,
               neighbor_state_code,
               neighbor_state_code_descr,
               number_lanes,
               number_lanes_under,
               ol_north_right_ramp_ft,
               ol_north_right_ramp_in,
               ol_permit_left_ramp_ft,
               ol_permit_left_ramp_in,
               ol_permit_north_ft,
               ol_permit_north_in,
               ol_permit_other_ft,
               ol_permit_other_in,
               ol_permit_portal_north_ft,
               ol_permit_portal_north_in,
               ol_permit_portal_south_ft,
               ol_permit_portal_south_in,
               ol_permit_right_ramp_ft,
               ol_permit_right_ramp_in,
               ol_permit_south_ft,
               ol_permit_south_in,
               ol_north_main_posted,
               ol_north_other_posted,
               ol_north_ramp_posted,
               ol_portal_north_posted,
               ol_portal_south_posted,
               ol_south_main_posted,
               ol_south_other_posted,
               ol_south_ramp_posted,
               LR_POSTED_DATE,
               OL_NORTH_MAIN_POSTED_FT,
               OL_NORTH_MAIN_POSTED_IN,
               OL_NORTH_OTHER_POSTED_FT,
               OL_NORTH_OTHER_POSTED_IN,
               OL_NORTH_RAMP_POSTED_FT,
               OL_NORTH_RAMP_POSTED_IN,
               OL_PORTAL_NORTH_POSTED_FT,
               OL_PORTAL_NORTH_POSTED_IN,
               OL_PORTAL_SOUTH_POSTED_FT,
               OL_PORTAL_SOUTH_POSTED_IN,
               OL_SOUTH_MAIN_POSTED_FT,
               OL_SOUTH_MAIN_POSTED_IN,
               OL_SOUTH_OTHER_POSTED_FT,
               OL_SOUTH_OTHER_POSTED_IN,
               OL_SOUTH_RAMP_POSTED_FT,
               OL_SOUTH_RAMP_POSTED_IN,
               on_base_highway_network,
               on_base_highway_network_descr,
               operating_rating,
               operating_rating_type,
               operating_rating_type_desc,
               owner,
               owner_descr,
               parallel_structure_desig,
               parallel_structure_desig_descr,
               parent_asset,
               pier_protection_rating,
               pier_protection_rating_descr,
               posted_bridge_indicator,
               posted_bridge_indicator_descr,
               post_type,
               post_type_descr,
               posted,
               posted_weight_tons,
               posted_1_truck,
               posted_4_axle,
               posted_spacing,
               posted_5axle_crane,
               posted_5axle_crane_dolly,
               rail_rating,
               rail_rating_descr,
               remaining_service_life,
               score_date,
               scour_rating,
               scour_rating_descr,
               si_inspection_required,
               si_inspection_frequency,
               si_last_inspection,
               skew_angle,
               status,
               status_descr,
               structural_evaluation,
               structural_evaluation_descr,
               structure_flared,
               structure_flared_descr,
               structure_open,
               structure_open_descr,
               subcategory,
               substructure_rating,
               substructure_rating_descr,
               superstructure_rating,
               superstructure_rating_descr,
               temp_stucture_desig,
               temp_structure_desig_descr,
               toll,
               toll_descr,
               traffic_direction_on_bridge,
               traffic_direction_on_descr,
               transition_rating,
               transition_rating_descr,
               truck_weight_post_limit,
               type_of_service_on,
               type_of_service_on_descr,
               type_of_service_under,
               type_of_service_under_descr,
               underclearance_rating,
               underclearance_rating_descr,
               underwater_inspection_done,
               userbrdg_maintainer,
               userbrdg_maintainer_descr,
               userbrdg_owner,
               userbrdg_owner_descr,
               uw_inspection_required,
               uw_inspection_frequency,
               uw_last_inspection,
               vehicle_height_over,
               vehicle_height_under,
               vehicle_load_limit,
               waterway_adequacy_rating,
               waterway_adequacy_rating_descr,
               width,
               width_curb_to_curb,
               year_built,
               year_reconstructed
          FROM ibridges_staging
        MINUS
        SELECT bridge_number,
               bridge_name,
               abut_to_abut_detour,
               app_guardrail_end_rating,
               app_guardrail_end_rating_descr,
               app_guardrail_rating,
               app_guardrail_rating_descr,
               app_road_align_rating,
               app_road_align_rating_descr,
               approach_roadway_width,
               approach_span_design,
               approach_span_design_descr,
               approach_span_material,
               approach_span_material_descr,
               approach_span_number,
               asset_status,
               asset_status_descr,
               asset_type,
               border_bridge_number,
               border_bridge_percent_resp,
               bridge_condition_score,
               bridge_group,
               bridge_indicator,
               bridge_length,
               bridge_median,
               bridge_median_descr,
               bridge_on_off_system,
               bridge_on_off_system_descr,
               bridge_posting,
               bridge_posting_descr,
               bridge_posting_score,
               bridge_reliability_score,
               channel_rating,
               channel_rating_descr,
               clear_span_length,
               co_maintainer,
               co_maintainer_descr,
               co_owner,
               co_owner_descr,
               culvert_rating,
               culvert_rating_descr,
               curb_sidewalk_width_left,
               curb_sidewalk_width_right,
               year_last_painted,
               year_ws_replaced,
               date_needed,
               deck_area,
               deck_geometry_rating,
               deck_geometry_rating_descr,
               deck_membrane_type,
               deck_membrane_type_descr,
               deck_protection_code,
               deck_protection_descr,
               deck_rating,
               deck_rating_descr,
               deck_structure_type,
               deck_structure_type_descr,
               deck_surface_type,
               deck_surface_type_descr,
               design_load,
               design_load_descr,
               detour_length,
               fc_inspection_required,
               fc_inspection_frequency,
               fc_last_inspection,
               feature_on_structure,
               feature_under_structure,
               federal_land_hwy,
               federal_land_hwy_descr,
               federal_sufficiency_rating,
               fips_region,
               fips_region_descr,
               fips_state_code,
               fips_state_code_desc,
               funding_eligibility,
               geographic_region,
               geographic_region_descr,
               historical_significance,
               historical_significance_descr,
               horizontal_clearance,
               inspection_date,
               inspection_frequency,
               inventory_rating,
               inventory_rating_type,
               inventory_rating_type_descr,
               invrte_adt,
               invrte_adt_truck_percent,
               invrte_adt_yr,
               invrte_dirsuffix,
               invrte_dirsuffix_descr,
               invrte_functionclass,
               invrte_functionclass_descr,
               invrte_on_nhs,
               invrte_on_nhs_descr,
               invrte_lrs_rtenum,
               invrte_lrs_subrtenum,
               invrte_rectype,
               invrte_rtenum,
               invrte_on_strahnet,
               invrte_on_strahnet_descr,
               invrte_on_trucknet,
               invrte_on_trucknet_descr,
               kind_of_highway_on,
               kind_of_highway_on_descr,
               latitude,
               length_max_span,
               level_of_service_on,
               level_of_service_on_descr,
               location_description,
               longitude,
               lr_ev2_rating, 
               lr_ev3_rating,
               maintainer,
               maintainer_descr,
               maintenance_region,
               maintenance_region_descr,
               main_span_design,
               main_span_design_descr,
               main_span_material,
               main_span_material_descr,
               main_span_number,
               milepoint,
               minor_span_code_descr,
               min_lat_under_clear_left,
               min_lat_under_clear_right,
               min_navclr_lift_brdg,
               min_vertical_clearance_on,
               min_vert_under_clearance,
               min_vert_under_ref_feature,
               min_vert_under_ref_feature_descr,
               MTRNS_ASSETNO_LEFT_RAMP,
               MTRNS_ASSETNO_N_OR_E,
               MTRNS_ASSETNO_OTHER,
               MTRNS_ASSETNO_PORTAL_N_OR_E,
               MTRNS_ASSETNO_PORTAL_S_OR_W,
               MTRNS_ASSETNO_RIGHT_RAMP,
               MTRNS_ASSETNO_S_OR_W,
               navigation_control,
               navigation_control_descr,
               navigation_horizontal,
               navigation_vertical,
               nbis_bridge_length,
               nbis_inspection_done,
               need,
               neighbor_state_code,
               neighbor_state_code_descr,
               number_lanes,
               number_lanes_under,
               ol_north_right_ramp_ft,
               ol_north_right_ramp_in,
               ol_permit_left_ramp_ft,
               ol_permit_left_ramp_in,
               ol_permit_north_ft,
               ol_permit_north_in,
               ol_permit_other_ft,
               ol_permit_other_in,
               ol_permit_portal_north_ft,
               ol_permit_portal_north_in,
               ol_permit_portal_south_ft,
               ol_permit_portal_south_in,
               ol_permit_right_ramp_ft,
               ol_permit_right_ramp_in,
               ol_permit_south_ft,
               ol_permit_south_in,
               ol_north_main_posted,
               ol_north_other_posted,
               ol_north_ramp_posted,
               ol_portal_north_posted,
               ol_portal_south_posted,
               ol_south_main_posted,
               ol_south_other_posted,
               ol_south_ramp_posted,
               LR_POSTED_DATE,
               OL_NORTH_MAIN_POSTED_FT,
               OL_NORTH_MAIN_POSTED_IN,
               OL_NORTH_OTHER_POSTED_FT,
               OL_NORTH_OTHER_POSTED_IN,
               OL_NORTH_RAMP_POSTED_FT,
               OL_NORTH_RAMP_POSTED_IN,
               OL_PORTAL_NORTH_POSTED_FT,
               OL_PORTAL_NORTH_POSTED_IN,
               OL_PORTAL_SOUTH_POSTED_FT,
               OL_PORTAL_SOUTH_POSTED_IN,
               OL_SOUTH_MAIN_POSTED_FT,
               OL_SOUTH_MAIN_POSTED_IN,
               OL_SOUTH_OTHER_POSTED_FT,
               OL_SOUTH_OTHER_POSTED_IN,
               OL_SOUTH_RAMP_POSTED_FT,
               OL_SOUTH_RAMP_POSTED_IN,
               on_base_highway_network,
               on_base_highway_network_descr,
               operating_rating,
               operating_rating_type,
               operating_rating_type_desc,
               owner,
               owner_descr,
               parallel_structure_desig,
               parallel_structure_desig_descr,
               parent_asset,
               pier_protection_rating,
               pier_protection_rating_descr,
               posted_bridge_indicator,
               posted_bridge_indicator_descr,
               post_type,
               post_type_descr,
               posted,
               posted_weight_tons,
               posted_1_truck,
               posted_4_axle,
               posted_spacing,
               posted_5axle_crane,
               posted_5axle_crane_dolly,
               rail_rating,
               rail_rating_descr,
               remaining_service_life,
               score_date,
               scour_rating,
               scour_rating_descr,
               si_inspection_required,
               si_inspection_frequency,
               si_last_inspection,
               skew_angle,
               status,
               status_descr,
               structural_evaluation,
               structural_evaluation_descr,
               structure_flared,
               structure_flared_descr,
               structure_open,
               structure_open_descr,
               subcategory,
               substructure_rating,
               substructure_rating_descr,
               superstructure_rating,
               superstructure_rating_descr,
               temp_stucture_desig,
               temp_structure_desig_descr,
               toll,
               toll_descr,
               traffic_direction_on_bridge,
               traffic_direction_on_descr,
               transition_rating,
               transition_rating_descr,
               truck_weight_post_limit,
               type_of_service_on,
               type_of_service_on_descr,
               type_of_service_under,
               type_of_service_under_descr,
               underclearance_rating,
               underclearance_rating_descr,
               underwater_inspection_done,
               userbrdg_maintainer,
               userbrdg_maintainer_descr,
               userbrdg_owner,
               userbrdg_owner_descr,
               uw_inspection_required,
               uw_inspection_frequency,
               uw_last_inspection,
               vehicle_height_over,
               vehicle_height_under,
               vehicle_load_limit,
               waterway_adequacy_rating,
               waterway_adequacy_rating_descr,
               width,
               width_curb_to_curb,
               year_built,
               year_reconstructed
          FROM ibridges_history
         WHERE end_date IS NULL;


    CURSOR retired_bridges
    IS
        SELECT bridge_number
          FROM ibridges_history
         WHERE end_date IS NULL
        MINUS
        SELECT bridge_number FROM ibridges_staging;

    cntr_retired             NUMBER (5) := 0;
    cntr                     NUMBER (5) := 0;
    cntr_updated             NUMBER (5) := 0;
    cntr_added               NUMBER (5) := 0;
    start_time               DATE := SYSDATE;
    threshold_message        VARCHAR2 (200) := NULL;
    err_log_message          VARCHAR2 (200) := NULL;
    errlog_count             NUMBER := 0;
    g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                VARCHAR2 (30) := 'IBRIDGES_DAILY_REFRESH';
    g_object                 VARCHAR2 (20) := 'IBRIDGES';
    V_flat_file_counts_txt   VARCHAR2 (1000) := NULL;
    initial_number_lanes     NUMBER (5) := 0;

    current_year             NUMBER;
    surrogate_key            NUMBER;
BEGIN
    SELECT MAX (snapshot_year) INTO current_year FROM ibridges_history;
    check_bridge_extract;

    IF staging_already_loaded = 'N'
    THEN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE ibridges_history_error_log';

        -- weekdays, refresh bridge information from InspectTech
        load_ibridge_staging;
        load_ibridge_staging_scores;
    END IF;

    FOR rec IN bridge_changes
    LOOP
        cntr := cntr + 1;
    END LOOP;

    IF cntr < cntr_threshold
    THEN
        ibridge_diffs;

        FOR rec IN bridge_changes
        LOOP
            SELECT COUNT (*)
              INTO cntr
              FROM ibridges_history
             WHERE bridge_number = rec.bridge_number AND end_date IS NULL;

            IF cntr > 0
            THEN -- update the existing bridge that has some attributes that have changed
                BEGIN
                    UPDATE ibridges_history
                       SET date_modified = start_time,
                           modified_by = 'IBRIDGES_DAILY_REFRESH',
                           abut_to_abut_detour = rec.abut_to_abut_detour,
                           app_guardrail_end_rating =
                               rec.app_guardrail_end_rating,
                           app_guardrail_end_rating_descr =
                               rec.app_guardrail_end_rating_descr,
                           app_guardrail_rating = rec.app_guardrail_rating,
                           app_guardrail_rating_descr =
                               rec.app_guardrail_rating_descr,
                           app_road_align_rating = rec.app_road_align_rating,
                           app_road_align_rating_descr =
                               rec.app_road_align_rating_descr,
                           approach_roadway_width =
                               rec.approach_roadway_width,
                           approach_span_design = rec.approach_span_design,
                           approach_span_design_descr =
                               rec.approach_span_design_descr,
                           approach_span_material =
                               rec.approach_span_material,
                           approach_span_material_descr =
                               rec.approach_span_material_descr,
                           approach_span_number = rec.approach_span_number,
                           asset_status = rec.asset_status,
                           asset_status_descr = rec.asset_status_descr,
                           asset_type = rec.asset_type,
                           border_bridge_number = rec.border_bridge_number,
                           border_bridge_percent_resp =
                               rec.border_bridge_percent_resp,
                           bridge_condition_score =
                               rec.bridge_condition_score,
                           bridge_group = rec.bridge_group,
                           bridge_indicator = rec.bridge_indicator,
                           bridge_length = rec.bridge_length,
                           bridge_median = rec.bridge_median,
                           bridge_median_descr = rec.bridge_median_descr,
                           bridge_name = rec.bridge_name,
                           bridge_on_off_system = rec.bridge_on_off_system,
                           bridge_on_off_system_descr =
                               rec.bridge_on_off_system_descr,
                           bridge_posting = rec.bridge_posting,
                           bridge_posting_descr = rec.bridge_posting_descr,
                           bridge_posting_score = rec.bridge_posting_score,
                           bridge_reliability_score =
                               rec.bridge_reliability_score,
                           channel_rating = rec.channel_rating,
                           channel_rating_descr = rec.channel_rating_descr,
                           clear_span_length = rec.clear_span_length,
                           co_maintainer = rec.co_maintainer,
                           co_maintainer_descr = rec.co_maintainer_descr,
                           co_owner = rec.co_owner,
                           co_owner_descr = rec.co_owner_descr,
                           culvert_rating = rec.culvert_rating,
                           culvert_rating_descr = rec.culvert_rating_descr,
                           curb_sidewalk_width_left =
                               rec.curb_sidewalk_width_left,
                           curb_sidewalk_width_right =
                               rec.curb_sidewalk_width_right,
                           year_last_painted = rec.year_last_painted,
                           year_ws_replaced = rec.year_ws_replaced,
                           date_needed = rec.date_needed,
                           deck_area = rec.deck_area,
                           deck_geometry_rating = rec.deck_geometry_rating,
                           deck_geometry_rating_descr =
                               rec.deck_geometry_rating_descr,
                           deck_membrane_type = rec.deck_membrane_type,
                           deck_membrane_type_descr =
                               rec.deck_membrane_type_descr,
                           deck_protection_code = rec.deck_protection_code,
                           deck_protection_descr = rec.deck_protection_descr,
                           deck_rating = rec.deck_rating,
                           deck_rating_descr = rec.deck_rating_descr,
                           deck_structure_type = rec.deck_structure_type,
                           deck_structure_type_descr =
                               rec.deck_structure_type_descr,
                           deck_surface_type = rec.deck_surface_type,
                           deck_surface_type_descr =
                               rec.deck_surface_type_descr,
                           design_load = rec.design_load,
                           design_load_descr = rec.design_load_descr,
                           detour_length = rec.detour_length,
                           fc_inspection_required =
                               rec.fc_inspection_required,
                           fc_inspection_frequency =
                               rec.fc_inspection_frequency,
                           fc_last_inspection = rec.fc_last_inspection,
                           feature_on_structure = rec.feature_on_structure,
                           feature_under_structure =
                               rec.feature_under_structure,
                           federal_land_hwy = rec.federal_land_hwy,
                           federal_land_hwy_descr =
                               rec.federal_land_hwy_descr,
                           federal_sufficiency_rating =
                               rec.federal_sufficiency_rating,
                           fips_region = rec.fips_region,
                           fips_region_descr = rec.fips_region_descr,
                           fips_state_code = rec.fips_state_code,
                           fips_state_code_desc = rec.fips_state_code_desc,
                           funding_eligibility = rec.funding_eligibility,
                           geographic_region = rec.geographic_region,
                           geographic_region_descr =
                               rec.geographic_region_descr,
                           historical_significance =
                               rec.historical_significance,
                           historical_significance_descr =
                               rec.historical_significance_descr,
                           horizontal_clearance = rec.horizontal_clearance,
                           inspection_date = rec.inspection_date,
                           inspection_frequency = rec.inspection_frequency,
                           inventory_rating = rec.inventory_rating,
                           inventory_rating_type = rec.inventory_rating_type,
                           inventory_rating_type_descr =
                               rec.inventory_rating_type_descr,
                           invrte_adt = rec.invrte_adt,
                           invrte_adt_truck_percent =
                               rec.invrte_adt_truck_percent,
                           invrte_adt_yr = rec.invrte_adt_yr,
                           invrte_dirsuffix = rec.invrte_dirsuffix,
                           invrte_dirsuffix_descr =
                               rec.invrte_dirsuffix_descr,
                           invrte_functionclass = rec.invrte_functionclass,
                           invrte_functionclass_descr =
                               rec.invrte_functionclass_descr,
                           invrte_on_nhs = rec.invrte_on_nhs,
                           invrte_on_nhs_descr = rec.invrte_on_nhs_descr,
                           invrte_lrs_rtenum = rec.invrte_lrs_rtenum,
                           invrte_lrs_subrtenum = rec.invrte_lrs_subrtenum,
                           invrte_rectype = rec.invrte_rectype,
                           invrte_rtenum = rec.invrte_rtenum,
                           invrte_on_strahnet = rec.invrte_on_strahnet,
                           invrte_on_strahnet_descr =
                               rec.invrte_on_strahnet_descr,
                           invrte_on_trucknet = rec.invrte_on_trucknet,
                           invrte_on_trucknet_descr =
                               rec.invrte_on_trucknet_descr,
                           kind_of_highway_on = rec.kind_of_highway_on,
                           kind_of_highway_on_descr =
                               rec.kind_of_highway_on_descr,
                           latitude = rec.latitude,
                           length_max_span = rec.length_max_span,
                           level_of_service_on = rec.level_of_service_on,
                           level_of_service_on_descr =
                               rec.level_of_service_on_descr,
                           location_description = rec.location_description,
                           longitude = rec.longitude,
                           lr_ev2_rating = rec.lr_ev2_rating, 
                           lr_ev3_rating = rec.lr_ev3_rating,
                           maintainer = rec.maintainer,
                           maintainer_descr = rec.maintainer_descr,
                           maintenance_region = rec.maintenance_region,
                           maintenance_region_descr =
                               rec.maintenance_region_descr,
                           main_span_design = rec.main_span_design,
                           main_span_design_descr =
                               rec.main_span_design_descr,
                           main_span_material = rec.main_span_material,
                           main_span_material_descr =
                               rec.main_span_material_descr,
                           main_span_number = rec.main_span_number,
                           milepoint = rec.milepoint,
                           minor_span_code_descr = rec.minor_span_code_descr,
                           min_lat_under_clear_left =
                               rec.min_lat_under_clear_left,
                           min_lat_under_clear_right =
                               rec.min_lat_under_clear_right,
                           min_navclr_lift_brdg = rec.min_navclr_lift_brdg,
                           min_vertical_clearance_on =
                               rec.min_vertical_clearance_on,
                           min_vert_under_clearance =
                               rec.min_vert_under_clearance,
                           min_vert_under_ref_feature =
                               rec.min_vert_under_ref_feature,
                           min_vert_under_ref_feature_descr =
                               rec.min_vert_under_ref_feature_descr,
                           MTRNS_ASSETNO_LEFT_RAMP =
                               rec.MTRNS_ASSETNO_LEFT_RAMP,
                           MTRNS_ASSETNO_N_OR_E = rec.MTRNS_ASSETNO_N_OR_E,
                           MTRNS_ASSETNO_OTHER = rec.MTRNS_ASSETNO_OTHER,
                           MTRNS_ASSETNO_PORTAL_N_OR_E =
                               rec.MTRNS_ASSETNO_PORTAL_N_OR_E,
                           MTRNS_ASSETNO_PORTAL_S_OR_W =
                               rec.MTRNS_ASSETNO_PORTAL_S_OR_W,
                           MTRNS_ASSETNO_RIGHT_RAMP =
                               rec.MTRNS_ASSETNO_RIGHT_RAMP,
                           MTRNS_ASSETNO_S_OR_W = rec.MTRNS_ASSETNO_S_OR_W,
                           navigation_control = rec.navigation_control,
                           navigation_control_descr =
                               rec.navigation_control_descr,
                           navigation_horizontal = rec.navigation_horizontal,
                           navigation_vertical = rec.navigation_vertical,
                           nbis_inspection_done = rec.nbis_inspection_done,
                           nbis_bridge_length = rec.nbis_bridge_length,
                           need = rec.need,
                           neighbor_state_code = rec.neighbor_state_code,
                           neighbor_state_code_descr =
                               rec.neighbor_state_code_descr,
                           number_lanes = rec.number_lanes,
                           number_lanes_under = rec.number_lanes_under,
                           ol_north_right_ramp_ft =
                               rec.ol_north_right_ramp_ft,
                           ol_north_right_ramp_in =
                               rec.ol_north_right_ramp_in,
                           ol_permit_left_ramp_ft =
                               rec.ol_permit_left_ramp_ft,
                           ol_permit_left_ramp_in =
                               rec.ol_permit_left_ramp_in,
                           ol_permit_north_ft = rec.ol_permit_north_ft,
                           ol_permit_north_in = rec.ol_permit_north_in,
                           ol_permit_other_ft = rec.ol_permit_other_ft,
                           ol_permit_other_in = rec.ol_permit_other_in,
                           ol_permit_portal_north_ft =
                               rec.ol_permit_portal_north_ft,
                           ol_permit_portal_north_in =
                               rec.ol_permit_portal_north_in,
                           ol_permit_portal_south_ft =
                               rec.ol_permit_portal_south_ft,
                           ol_permit_portal_south_in =
                               rec.ol_permit_portal_south_in,
                           ol_permit_right_ramp_ft =
                               rec.ol_permit_right_ramp_ft,
                           ol_permit_right_ramp_in =
                               rec.ol_permit_right_ramp_in,
                           ol_permit_south_ft = rec.ol_permit_south_ft,
                           ol_permit_south_in = rec.ol_permit_south_in,
                           ol_north_main_posted = rec.ol_north_main_posted,
                           ol_north_other_posted = rec.ol_north_other_posted,
                           ol_north_ramp_posted = rec.ol_north_ramp_posted,
                           ol_portal_north_posted =
                               rec.ol_portal_north_posted,
                           ol_portal_south_posted =
                               rec.ol_portal_south_posted,
                           ol_south_main_posted = rec.ol_south_main_posted,
                           ol_south_other_posted = rec.ol_south_other_posted,
                           ol_south_ramp_posted = rec.ol_south_ramp_posted,
                           LR_POSTED_DATE = rec.LR_POSTED_DATE,
                           OL_NORTH_MAIN_POSTED_FT =
                               rec.OL_NORTH_MAIN_POSTED_FT,
                           OL_NORTH_MAIN_POSTED_IN =
                               rec.OL_NORTH_MAIN_POSTED_IN,
                           OL_NORTH_OTHER_POSTED_FT =
                               rec.OL_NORTH_OTHER_POSTED_FT,
                           OL_NORTH_OTHER_POSTED_IN =
                               rec.OL_NORTH_OTHER_POSTED_IN,
                           OL_NORTH_RAMP_POSTED_FT =
                               rec.OL_NORTH_RAMP_POSTED_FT,
                           OL_NORTH_RAMP_POSTED_IN =
                               rec.OL_NORTH_RAMP_POSTED_IN,
                           OL_PORTAL_NORTH_POSTED_FT =
                               rec.OL_PORTAL_NORTH_POSTED_FT,
                           OL_PORTAL_NORTH_POSTED_IN =
                               rec.OL_PORTAL_NORTH_POSTED_IN,
                           OL_PORTAL_SOUTH_POSTED_FT =
                               rec.OL_PORTAL_SOUTH_POSTED_FT,
                           OL_PORTAL_SOUTH_POSTED_IN =
                               rec.OL_PORTAL_SOUTH_POSTED_IN,
                           OL_SOUTH_MAIN_POSTED_FT =
                               rec.OL_SOUTH_MAIN_POSTED_FT,
                           OL_SOUTH_MAIN_POSTED_IN =
                               rec.OL_SOUTH_MAIN_POSTED_IN,
                           OL_SOUTH_OTHER_POSTED_FT =
                               rec.OL_SOUTH_OTHER_POSTED_FT,
                           OL_SOUTH_OTHER_POSTED_IN =
                               rec.OL_SOUTH_OTHER_POSTED_IN,
                           OL_SOUTH_RAMP_POSTED_FT =
                               rec.oL_SOUTH_RAMP_POSTED_FT,
                           OL_SOUTH_RAMP_POSTED_IN =
                               rec.OL_SOUTH_RAMP_POSTED_IN,
                           on_base_highway_network =
                               rec.on_base_highway_network,
                           on_base_highway_network_descr =
                               rec.on_base_highway_network_descr,
                           operating_rating = rec.operating_rating,
                           operating_rating_type = rec.operating_rating_type,
                           operating_rating_type_desc =
                               rec.operating_rating_type_desc,
                           owner = rec.owner,
                           owner_descr = rec.owner_descr,
                           parallel_structure_desig =
                               rec.parallel_structure_desig,
                           parallel_structure_desig_descr =
                               rec.parallel_structure_desig_descr,
                           parent_asset = rec.parent_asset,
                           pier_protection_rating =
                               rec.pier_protection_rating,
                           pier_protection_rating_descr =
                               rec.pier_protection_rating_descr,
                           posted_bridge_indicator =
                               rec.posted_bridge_indicator,
                           posted_bridge_indicator_descr =
                               rec.posted_bridge_indicator_descr,
                           post_type = rec.post_type,
                           post_type_descr = rec.post_type_descr,
                           posted = rec.posted,
                           posted_weight_tons = rec.posted_weight_tons,
                           posted_1_truck = rec.posted_1_truck,
                           posted_4_axle = rec.posted_4_axle,
                           posted_spacing = rec.posted_spacing,
                           posted_5axle_crane = rec.posted_5axle_crane,
                           posted_5axle_crane_dolly =
                               rec.posted_5axle_crane_dolly,
                           rail_rating = rec.rail_rating,
                           rail_rating_descr = rec.rail_rating_descr,
                           remaining_service_life =
                               rec.remaining_service_life,
                           score_date = rec.score_date,
                           scour_rating = rec.scour_rating,
                           scour_rating_descr = rec.scour_rating_descr,
                           si_inspection_required =
                               rec.si_inspection_required,
                           si_inspection_frequency =
                               rec.si_inspection_frequency,
                           si_last_inspection = rec.si_last_inspection,
                           skew_angle = rec.skew_angle,
                           status = rec.status,
                           status_descr = rec.status_descr,
                           structural_evaluation = rec.structural_evaluation,
                           structural_evaluation_descr =
                               rec.structural_evaluation_descr,
                           structure_flared = rec.structure_flared,
                           structure_flared_descr =
                               rec.structure_flared_descr,
                           structure_open = rec.structure_open,
                           structure_open_descr = rec.structure_open_descr,
                           subcategory = rec.subcategory,
                           substructure_rating = rec.substructure_rating,
                           substructure_rating_descr =
                               rec.substructure_rating_descr,
                           superstructure_rating = rec.superstructure_rating,
                           superstructure_rating_descr =
                               rec.superstructure_rating_descr,
                           temp_stucture_desig = rec.temp_stucture_desig,
                           temp_structure_desig_descr =
                               rec.temp_structure_desig_descr,
                           toll = rec.toll,
                           toll_descr = rec.toll_descr,
                           traffic_direction_on_bridge =
                               rec.traffic_direction_on_bridge,
                           traffic_direction_on_descr =
                               rec.traffic_direction_on_descr,
                           transition_rating = rec.transition_rating,
                           transition_rating_descr =
                               rec.transition_rating_descr,
                           truck_weight_post_limit =
                               rec.truck_weight_post_limit,
                           type_of_service_on = rec.type_of_service_on,
                           type_of_service_on_descr =
                               rec.type_of_service_on_descr,
                           type_of_service_under = rec.type_of_service_under,
                           type_of_service_under_descr =
                               rec.type_of_service_under_descr,
                           underwater_inspection_done =
                               rec.underwater_inspection_done,
                           underclearance_rating = rec.underclearance_rating,
                           underclearance_rating_descr =
                               rec.underclearance_rating_descr,
                           userbrdg_maintainer = rec.userbrdg_maintainer,
                           userbrdg_maintainer_descr =
                               rec.userbrdg_maintainer_descr,
                           userbrdg_owner = SUBSTR (rec.userbrdg_owner, 1, 1),
                           userbrdg_owner_descr = rec.userbrdg_owner_descr,
                           uw_inspection_required =
                               rec.uw_inspection_required,
                           uw_inspection_frequency =
                               rec.uw_inspection_frequency,
                           uw_last_inspection = rec.uw_last_inspection,
                           vehicle_height_over = rec.vehicle_height_over,
                           vehicle_height_under = rec.vehicle_height_under,
                           vehicle_load_limit = rec.vehicle_load_limit,
                           waterway_adequacy_rating =
                               rec.waterway_adequacy_rating,
                           waterway_adequacy_rating_descr =
                               rec.waterway_adequacy_rating_descr,
                           width = rec.width,
                           width_curb_to_curb = rec.width_curb_to_curb,
                           year_built = rec.year_built,
                           year_reconstructed = rec.year_reconstructed
                     WHERE     bridge_number = rec.bridge_number
                           AND end_date IS NULL
                       LOG ERRORS INTO ibridges_history_error_log
                               (   'IBridges Daily Refresh - Update bridge: '
                                || SYSDATE)
                               REJECT LIMIT 100;

                    cntr_updated := cntr_updated + 1;
                END;                              -- update of existing bridge
            ELSE                        -- new bridge not yet in the data mart
                BEGIN
                    cntr_added := cntr_added + 1;

                    SELECT assets_sequence.NEXTVAL
                      INTO surrogate_key
                      FROM DUAL;

                    INSERT INTO ibridges_history (
                                    bridge_id,
                                    bridge_number,
                                    bridge_name,
                                    abut_to_abut_detour,
                                    app_guardrail_end_rating,
                                    app_guardrail_end_rating_descr,
                                    app_guardrail_rating,
                                    app_guardrail_rating_descr,
                                    app_road_align_rating,
                                    app_road_align_rating_descr,
                                    approach_roadway_width,
                                    approach_span_design,
                                    approach_span_design_descr,
                                    approach_span_material,
                                    approach_span_material_descr,
                                    approach_span_number,
                                    asset_status,
                                    asset_status_descr,
                                    asset_type,
                                    border_bridge_number,
                                    border_bridge_percent_resp,
                                    bridge_condition_score,
                                    bridge_group,
                                    bridge_indicator,
                                    bridge_length,
                                    bridge_median,
                                    bridge_median_descr,
                                    bridge_on_off_system,
                                    bridge_on_off_system_descr,
                                    bridge_posting,
                                    bridge_posting_descr,
                                    bridge_posting_score,
                                    bridge_reliability_score,
                                    channel_rating,
                                    channel_rating_descr,
                                    clear_span_length,
                                    co_maintainer,
                                    co_maintainer_descr,
                                    co_owner,
                                    co_owner_descr,
                                    culvert_rating,
                                    culvert_rating_descr,
                                    curb_sidewalk_width_left,
                                    curb_sidewalk_width_right,
                                    year_last_painted,
                                    year_ws_replaced,
                                    date_needed,
                                    deck_area,
                                    deck_geometry_rating,
                                    deck_geometry_rating_descr,
                                    deck_membrane_type,
                                    deck_membrane_type_descr,
                                    deck_protection_code,
                                    deck_protection_descr,
                                    deck_rating,
                                    deck_rating_descr,
                                    deck_structure_type,
                                    deck_structure_type_descr,
                                    deck_surface_type,
                                    deck_surface_type_descr,
                                    design_load,
                                    design_load_descr,
                                    detour_length,
                                    fc_inspection_required,
                                    fc_inspection_frequency,
                                    fc_last_inspection,
                                    feature_on_structure,
                                    feature_under_structure,
                                    federal_land_hwy,
                                    federal_land_hwy_descr,
                                    federal_sufficiency_rating,
                                    fips_region,
                                    fips_region_descr,
                                    fips_state_code,
                                    fips_state_code_desc,
                                    funding_eligibility,
                                    geographic_region,
                                    geographic_region_descr,
                                    historical_significance,
                                    historical_significance_descr,
                                    horizontal_clearance,
                                    inspection_date,
                                    inspection_frequency,
                                    inventory_rating,
                                    inventory_rating_type,
                                    inventory_rating_type_descr,
                                    invrte_adt,
                                    invrte_adt_truck_percent,
                                    invrte_adt_yr,
                                    invrte_dirsuffix,
                                    invrte_dirsuffix_descr,
                                    invrte_functionclass,
                                    invrte_functionclass_descr,
                                    invrte_on_nhs,
                                    invrte_on_nhs_descr,
                                    invrte_lrs_rtenum,
                                    invrte_lrs_subrtenum,
                                    invrte_rectype,
                                    invrte_rtenum,
                                    invrte_on_strahnet,
                                    invrte_on_strahnet_descr,
                                    invrte_on_trucknet,
                                    invrte_on_trucknet_descr,
                                    kind_of_highway_on,
                                    kind_of_highway_on_descr,
                                    latitude,
                                    length_max_span,
                                    level_of_service_on,
                                    level_of_service_on_descr,
                                    location_description,
                                    longitude,
                                    lr_ev2_rating,
                                    lr_ev3_rating,
                                    maintainer,
                                    maintainer_descr,
                                    maintenance_region,
                                    maintenance_region_descr,
                                    main_span_design,
                                    main_span_design_descr,
                                    main_span_material,
                                    main_span_material_descr,
                                    main_span_number,
                                    milepoint,
                                    minor_span_code_descr,
                                    min_lat_under_clear_left,
                                    min_lat_under_clear_right,
                                    min_navclr_lift_brdg,
                                    min_vertical_clearance_on,
                                    min_vert_under_clearance,
                                    min_vert_under_ref_feature,
                                    min_vert_under_ref_feature_descr,
                                    MTRNS_ASSETNO_LEFT_RAMP,
                                    MTRNS_ASSETNO_N_OR_E,
                                    MTRNS_ASSETNO_OTHER,
                                    MTRNS_ASSETNO_PORTAL_N_OR_E,
                                    MTRNS_ASSETNO_PORTAL_S_OR_W,
                                    MTRNS_ASSETNO_RIGHT_RAMP,
                                    MTRNS_ASSETNO_S_OR_W,
                                    navigation_control,
                                    navigation_control_descr,
                                    navigation_horizontal,
                                    navigation_vertical,
                                    nbis_bridge_length,
                                    nbis_inspection_done,
                                    need,
                                    neighbor_state_code,
                                    neighbor_state_code_descr,
                                    number_lanes,
                                    number_lanes_under,
                                    ol_north_right_ramp_ft,
                                    ol_north_right_ramp_in,
                                    ol_permit_left_ramp_ft,
                                    ol_permit_left_ramp_in,
                                    ol_permit_north_ft,
                                    ol_permit_north_in,
                                    ol_permit_other_ft,
                                    ol_permit_other_in,
                                    ol_permit_portal_north_ft,
                                    ol_permit_portal_north_in,
                                    ol_permit_portal_south_ft,
                                    ol_permit_portal_south_in,
                                    ol_permit_right_ramp_ft,
                                    ol_permit_right_ramp_in,
                                    ol_permit_south_ft,
                                    ol_permit_south_in,
                                    ol_north_main_posted,
                                    ol_north_other_posted,
                                    ol_north_ramp_posted,
                                    ol_portal_north_posted,
                                    ol_portal_south_posted,
                                    ol_south_main_posted,
                                    ol_south_other_posted,
                                    ol_south_ramp_posted,
                                    LR_POSTED_DATE,
                                    OL_NORTH_MAIN_POSTED_FT,
                                    OL_NORTH_MAIN_POSTED_IN,
                                    OL_NORTH_OTHER_POSTED_FT,
                                    OL_NORTH_OTHER_POSTED_IN,
                                    OL_NORTH_RAMP_POSTED_FT,
                                    OL_NORTH_RAMP_POSTED_IN,
                                    OL_PORTAL_NORTH_POSTED_FT,
                                    OL_PORTAL_NORTH_POSTED_IN,
                                    OL_PORTAL_SOUTH_POSTED_FT,
                                    OL_PORTAL_SOUTH_POSTED_IN,
                                    OL_SOUTH_MAIN_POSTED_FT,
                                    OL_SOUTH_MAIN_POSTED_IN,
                                    OL_SOUTH_OTHER_POSTED_FT,
                                    OL_SOUTH_OTHER_POSTED_IN,
                                    OL_SOUTH_RAMP_POSTED_FT,
                                    OL_SOUTH_RAMP_POSTED_IN,
                                    on_base_highway_network,
                                    on_base_highway_network_descr,
                                    operating_rating,
                                    operating_rating_type,
                                    operating_rating_type_desc,
                                    owner,
                                    owner_descr,
                                    parallel_structure_desig,
                                    parallel_structure_desig_descr,
                                    parent_asset,
                                    pier_protection_rating,
                                    pier_protection_rating_descr,
                                    posted_bridge_indicator,
                                    posted_bridge_indicator_descr,
                                    post_type,
                                    post_type_descr,
                                    posted,
                                    posted_weight_tons,
                                    posted_1_truck,
                                    posted_4_axle,
                                    posted_spacing,
                                    posted_5axle_crane,
                                    posted_5axle_crane_dolly,
                                    rail_rating,
                                    rail_rating_descr,
                                    remaining_service_life,
                                    score_date,
                                    scour_rating,
                                    scour_rating_descr,
                                    skew_angle,
                                    si_inspection_required,
                                    si_inspection_frequency,
                                    si_last_inspection,
                                    status,
                                    status_descr,
                                    structural_evaluation,
                                    structural_evaluation_descr,
                                    structure_flared,
                                    structure_flared_descr,
                                    structure_open,
                                    structure_open_descr,
                                    subcategory,
                                    substructure_rating,
                                    substructure_rating_descr,
                                    superstructure_rating,
                                    superstructure_rating_descr,
                                    temp_stucture_desig,
                                    temp_structure_desig_descr,
                                    toll,
                                    toll_descr,
                                    traffic_direction_on_bridge,
                                    traffic_direction_on_descr,
                                    transition_rating,
                                    transition_rating_descr,
                                    truck_weight_post_limit,
                                    type_of_service_on,
                                    type_of_service_on_descr,
                                    type_of_service_under,
                                    type_of_service_under_descr,
                                    underclearance_rating,
                                    underclearance_rating_descr,
                                    underwater_inspection_done,
                                    userbrdg_maintainer,
                                    userbrdg_maintainer_descr,
                                    userbrdg_owner,
                                    userbrdg_owner_descr,
                                    uw_inspection_required,
                                    uw_inspection_frequency,
                                    uw_last_inspection,
                                    vehicle_height_over,
                                    vehicle_height_under,
                                    vehicle_load_limit,
                                    waterway_adequacy_rating,
                                    waterway_adequacy_rating_descr,
                                    width,
                                    width_curb_to_curb,
                                    year_built,
                                    year_reconstructed,
                                    date_created,
                                    date_modified,
                                    created_by,
                                    end_date,
                                    modified_by,
                                    snapshot_year,
                                    start_date,
                                    state)
                             VALUES (surrogate_key,
                                     rec.bridge_number,
                                     rec.bridge_name,
                                     rec.abut_to_abut_detour,
                                     rec.app_guardrail_end_rating,
                                     rec.app_guardrail_end_rating_descr,
                                     rec.app_guardrail_rating,
                                     rec.app_guardrail_rating_descr,
                                     rec.app_road_align_rating,
                                     rec.app_road_align_rating_descr,
                                     rec.approach_roadway_width,
                                     rec.approach_span_design,
                                     rec.approach_span_design_descr,
                                     rec.approach_span_material,
                                     rec.approach_span_material_descr,
                                     rec.approach_span_number,
                                     rec.asset_status,
                                     rec.asset_status_descr,
                                     rec.asset_type,
                                     rec.border_bridge_number,
                                     rec.border_bridge_percent_resp,
                                     rec.bridge_condition_score,
                                     rec.bridge_group,
                                     rec.bridge_indicator,
                                     rec.bridge_length,
                                     rec.bridge_median,
                                     rec.bridge_median_descr,
                                     rec.bridge_on_off_system,
                                     rec.bridge_on_off_system_descr,
                                     rec.bridge_posting,
                                     rec.bridge_posting_descr,
                                     rec.bridge_posting_score,
                                     rec.bridge_reliability_score,
                                     rec.channel_rating,
                                     rec.channel_rating_descr,
                                     rec.clear_span_length,
                                     rec.co_maintainer,
                                     rec.co_maintainer_descr,
                                     rec.co_owner,
                                     rec.co_owner_descr,
                                     rec.culvert_rating,
                                     rec.culvert_rating_descr,
                                     rec.curb_sidewalk_width_left,
                                     rec.curb_sidewalk_width_right,
                                     rec.year_last_painted,
                                     rec.year_ws_replaced,
                                     rec.date_needed,
                                     rec.deck_area,
                                     rec.deck_geometry_rating,
                                     rec.deck_geometry_rating_descr,
                                     rec.deck_membrane_type,
                                     rec.deck_membrane_type_descr,
                                     rec.deck_protection_code,
                                     rec.deck_protection_descr,
                                     rec.deck_rating,
                                     rec.deck_rating_descr,
                                     rec.deck_structure_type,
                                     rec.deck_structure_type_descr,
                                     rec.deck_surface_type,
                                     rec.deck_surface_type_descr,
                                     rec.design_load,
                                     rec.design_load_descr,
                                     rec.detour_length,
                                     rec.fc_inspection_required,
                                     rec.fc_inspection_frequency,
                                     rec.fc_last_inspection,
                                     rec.feature_on_structure,
                                     rec.feature_under_structure,
                                     rec.federal_land_hwy,
                                     rec.federal_land_hwy_descr,
                                     rec.federal_sufficiency_rating,
                                     rec.fips_region,
                                     rec.fips_region_descr,
                                     rec.fips_state_code,
                                     rec.fips_state_code_desc,
                                     rec.funding_eligibility,
                                     rec.geographic_region,
                                     rec.geographic_region_descr,
                                     rec.historical_significance,
                                     rec.historical_significance_descr,
                                     rec.horizontal_clearance,
                                     rec.inspection_date,
                                     rec.inspection_frequency,
                                     rec.inventory_rating,
                                     rec.inventory_rating_type,
                                     rec.inventory_rating_type_descr,
                                     rec.invrte_adt,
                                     rec.invrte_adt_truck_percent,
                                     rec.invrte_adt_yr,
                                     rec.invrte_dirsuffix,
                                     rec.invrte_dirsuffix_descr,
                                     rec.invrte_functionclass,
                                     rec.invrte_functionclass_descr,
                                     rec.invrte_on_nhs,
                                     rec.invrte_on_nhs_descr,
                                     rec.invrte_lrs_rtenum,
                                     rec.invrte_lrs_subrtenum,
                                     rec.invrte_rectype,
                                     rec.invrte_rtenum,
                                     rec.invrte_on_strahnet,
                                     rec.invrte_on_strahnet_descr,
                                     rec.invrte_on_trucknet,
                                     rec.invrte_on_trucknet_descr,
                                     rec.kind_of_highway_on,
                                     rec.kind_of_highway_on_descr,
                                     rec.latitude,
                                     rec.length_max_span,
                                     rec.level_of_service_on,
                                     rec.level_of_service_on_descr,
                                     rec.location_description,
                                     rec.longitude,
                                     rec.lr_ev2_rating,
                                     rec.lr_ev3_rating,
                                     rec.maintainer,
                                     rec.maintainer_descr,
                                     rec.maintenance_region,
                                     rec.maintenance_region_descr,
                                     rec.main_span_design,
                                     rec.main_span_design_descr,
                                     rec.main_span_material,
                                     rec.main_span_material_descr,
                                     rec.main_span_number,
                                     rec.milepoint,
                                     rec.minor_span_code_descr,
                                     rec.min_lat_under_clear_left,
                                     rec.min_lat_under_clear_right,
                                     rec.min_navclr_lift_brdg,
                                     rec.min_vertical_clearance_on,
                                     rec.min_vert_under_clearance,
                                     rec.min_vert_under_ref_feature,
                                     rec.min_vert_under_ref_feature_descr,
                                     rec.MTRNS_ASSETNO_LEFT_RAMP,
                                     rec.MTRNS_ASSETNO_N_OR_E,
                                     rec.MTRNS_ASSETNO_OTHER,
                                     rec.MTRNS_ASSETNO_PORTAL_N_OR_E,
                                     rec.MTRNS_ASSETNO_PORTAL_S_OR_W,
                                     rec.MTRNS_ASSETNO_RIGHT_RAMP,
                                     rec.MTRNS_ASSETNO_S_OR_W,
                                     rec.navigation_control,
                                     rec.navigation_control_descr,
                                     rec.navigation_horizontal,
                                     rec.navigation_vertical,
                                     rec.nbis_bridge_length,
                                     rec.nbis_inspection_done,
                                     rec.need,
                                     rec.neighbor_state_code,
                                     rec.neighbor_state_code_descr,
                                     rec.number_lanes,
                                     rec.number_lanes_under,
                                     rec.ol_north_right_ramp_ft,
                                     rec.ol_north_right_ramp_in,
                                     rec.ol_permit_left_ramp_ft,
                                     rec.ol_permit_left_ramp_in,
                                     rec.ol_permit_north_ft,
                                     rec.ol_permit_north_in,
                                     rec.ol_permit_other_ft,
                                     rec.ol_permit_other_in,
                                     rec.ol_permit_portal_north_ft,
                                     rec.ol_permit_portal_north_in,
                                     rec.ol_permit_portal_south_ft,
                                     rec.ol_permit_portal_south_in,
                                     rec.ol_permit_right_ramp_ft,
                                     rec.ol_permit_right_ramp_in,
                                     rec.ol_permit_south_ft,
                                     rec.ol_permit_south_in,
                                     rec.ol_north_main_posted,
                                     rec.ol_north_other_posted,
                                     rec.ol_north_ramp_posted,
                                     rec.ol_portal_north_posted,
                                     rec.ol_portal_south_posted,
                                     rec.ol_south_main_posted,
                                     rec.ol_south_other_posted,
                                     rec.ol_south_ramp_posted,
                                     rec.LR_POSTED_DATE,
                                     rec.OL_NORTH_MAIN_POSTED_FT,
                                     rec.OL_NORTH_MAIN_POSTED_IN,
                                     rec.OL_NORTH_OTHER_POSTED_FT,
                                     rec.OL_NORTH_OTHER_POSTED_IN,
                                     rec.OL_NORTH_RAMP_POSTED_FT,
                                     rec.OL_NORTH_RAMP_POSTED_IN,
                                     rec.OL_PORTAL_NORTH_POSTED_FT,
                                     rec.OL_PORTAL_NORTH_POSTED_IN,
                                     rec.OL_PORTAL_SOUTH_POSTED_FT,
                                     rec.OL_PORTAL_SOUTH_POSTED_IN,
                                     rec.OL_SOUTH_MAIN_POSTED_FT,
                                     rec.OL_SOUTH_MAIN_POSTED_IN,
                                     rec.OL_SOUTH_OTHER_POSTED_FT,
                                     rec.OL_SOUTH_OTHER_POSTED_IN,
                                     rec.OL_SOUTH_RAMP_POSTED_FT,
                                     rec.OL_SOUTH_RAMP_POSTED_IN,
                                     rec.on_base_highway_network,
                                     rec.on_base_highway_network_descr,
                                     rec.operating_rating,
                                     rec.operating_rating_type,
                                     rec.operating_rating_type_desc,
                                     rec.owner,
                                     rec.owner_descr,
                                     rec.parallel_structure_desig,
                                     rec.parallel_structure_desig_descr,
                                     rec.parent_asset,
                                     rec.pier_protection_rating,
                                     rec.pier_protection_rating_descr,
                                     rec.posted_bridge_indicator,
                                     rec.posted_bridge_indicator_descr,
                                     rec.post_type,
                                     rec.post_type_descr,
                                     rec.posted,
                                     rec.posted_weight_tons,
                                     rec.posted_1_truck,
                                     rec.posted_4_axle,
                                     rec.posted_spacing,
                                     rec.posted_5axle_crane,
                                     rec.posted_5axle_crane_dolly,
                                     rec.rail_rating,
                                     rec.rail_rating_descr,
                                     rec.remaining_service_life,
                                     rec.score_date,
                                     rec.scour_rating,
                                     rec.scour_rating_descr,
                                     rec.skew_angle,
                                     rec.si_inspection_required,
                                     rec.si_inspection_frequency,
                                     rec.si_last_inspection,
                                     rec.status,
                                     rec.status_descr,
                                     rec.structural_evaluation,
                                     rec.structural_evaluation_descr,
                                     rec.structure_flared,
                                     rec.structure_flared_descr,
                                     rec.structure_open,
                                     rec.structure_open_descr,
                                     rec.subcategory,
                                     rec.substructure_rating,
                                     rec.substructure_rating_descr,
                                     rec.superstructure_rating,
                                     rec.superstructure_rating_descr,
                                     rec.temp_stucture_desig,
                                     rec.temp_structure_desig_descr,
                                     rec.toll,
                                     rec.toll_descr,
                                     rec.traffic_direction_on_bridge,
                                     rec.traffic_direction_on_descr,
                                     rec.transition_rating,
                                     rec.transition_rating_descr,
                                     rec.truck_weight_post_limit,
                                     rec.type_of_service_on,
                                     rec.type_of_service_on_descr,
                                     rec.type_of_service_under,
                                     rec.type_of_service_under_descr,
                                     rec.underclearance_rating,
                                     rec.underclearance_rating_descr,
                                     rec.underwater_inspection_done,
                                     rec.userbrdg_maintainer,
                                     rec.userbrdg_maintainer_descr,
                                     SUBSTR (rec.userbrdg_owner, 1, 1),
                                     rec.userbrdg_owner_descr,
                                     rec.uw_inspection_required,
                                     rec.uw_inspection_frequency,
                                     rec.uw_last_inspection,
                                     rec.vehicle_height_over,
                                     rec.vehicle_height_under,
                                     rec.vehicle_load_limit,
                                     rec.waterway_adequacy_rating,
                                     rec.waterway_adequacy_rating_descr,
                                     rec.width,
                                     rec.width_curb_to_curb,
                                     rec.year_built,
                                     rec.year_reconstructed,
                                     start_time             /* date_created */
                                               ,
                                     NULL                    /*date_modified*/
                                         ,
                                     'IBRIDGES_DAILY_REFRESH'   /*created_by*/
                                                             ,
                                     NULL                       /* end_date */
                                         ,
                                     NULL                    /* modified_by */
                                         ,
                                     current_year            /*snapshot_year*/
                                                 ,
                                     start_time                 /*start_date*/
                                               ,
                                     'CURRENT'                       /*state*/
                                              )
                            LOG ERRORS INTO IBRIDGES_HISTORY_ERROR_LOG
                                    (   'INSERT IBRIDGES DAILY REFRESH '
                                     || SYSDATE)
                                    REJECT LIMIT 100;



                    INSERT INTO ibridges_changes                 -- log insert
                                                 (bridge_id,
                                                  bridge_number,
                                                  change_type,
                                                  change_date,
                                                  column_name,
                                                  modified_by,
                                                  old_value,
                                                  new_value)
                         VALUES (surrogate_key,
                                 rec.bridge_number,
                                 'I',
                                 start_time,
                                 NULL,
                                 'IBRIDGES_REFRESH',
                                 NULL,
                                 NULL);
                END;                                      -- insert new bridge
            END IF;
        END LOOP;

        COMMIT;

        FOR rec IN retired_bridges
        LOOP       -- Bridges that have been retired (set to S630-0 in Pontis)
            SELECT bridge_id
              INTO surrogate_key
              FROM ibridges_history
             WHERE bridge_number = rec.bridge_number AND end_date IS NULL;

            UPDATE ibridges_history
               SET end_date = start_time,
                   date_modified = start_time,
                   state = 'RETIRED'
             WHERE bridge_number = rec.bridge_number AND end_date IS NULL;

            INSERT INTO ibridges_changes                        -- log deletes
                                         (bridge_id,
                                          bridge_number,
                                          change_type,
                                          change_date,
                                          column_name,
                                          modified_by,
                                          old_value,
                                          new_value)
                 VALUES (surrogate_key,
                         rec.bridge_number,
                         'D',
                         start_time,
                         NULL,
                         'IBRIDGES_REFRESH',
                         NULL,
                         NULL);

            cntr_retired := cntr_retired + 1;
        END LOOP;                                -- processing retired bridges

        COMMIT;

        load_bridge_inspections;
        load_element_inspections;
        load_bridge_program_history;
        load_workplan_review;
        load_ibridge_inspection_date;
        rail_bridges_daily_refresh;
--        update_railway_bridges;  cleanup 4/5/23
        load_bridge_repairs;
        update_archived_bridges;
        monitor_routine_inspections;
        monitor_bridge_changes;
        load_retaining_walls;
        

        COMMIT;


        SELECT COUNT (*) INTO cntr FROM iBRIDGES_HISTORY;


        V_flat_file_counts_txt :=
               'IBRIDGES: '
            || 'Total Rows: '
            || cntr
            || ' Added: '
            || cntr_added
            || ' Updated: '
            || cntr_updated
            || ' Retired:  '
            || cntr_retired;

        WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
            OWNER         => 'WH_ASSETS',
            OBJECT_NAME   => 'IBRIDGES_HISTORY',
            object_cnt    => cntr,
            add_cnt       => cntr_added,
            update_cnt    => cntr_updated,
            proc          => $$PLSQL_UNIT,
            start_time    => start_time);
        wh_common.pkg_common_utilities.EXIT_AND_REPORT (
            $$PLSQL_UNIT,
            'NORMAL',
            V_flat_file_counts_txt);
    ELSE                                           -- if cntr < cntr_threshold
        threshold_message :=
               'Unexpected High Update Volume: '
            || cntr
            || ' Update Threshold: '
            || cntr_threshold
            || '. ';

        INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                        ERR_MODULE,
                                        ERR_OID,
                                        ERR_MESSAGE)
             VALUES (SYSDATE,
                     $$PLSQL_UNIT,
                     'WH_ASSETS',
                     threshold_message);

        COMMIT;
        wh_common.pkg_common_utilities.exit_and_report ($$PLSQL_UNIT,
                                                        'FAILURE',
                                                        threshold_message);
        RAISE_APPLICATION_ERROR (-20050, threshold_message);
    END IF;                                        -- if cntr < cntr_threshold

    -- Check error logs for quality errors
    -- Check ibridges history error log for quality errors

    SELECT COUNT (*)
      INTO errlog_count
      FROM wh_assets.ibridges_history_error_log;

    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in ibridges_history_error_log';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'IBRIDGES_DAILY_REFRESH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('IBRIDGES_HISTORY_ERROR_LOG',
                         'Invalid data - check error log',
                         g_jobname,
                         start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

    -- Check bridge inspections error log for quality errors

    SELECT COUNT (*)
      INTO errlog_count
      FROM wh_assets.BRIDGE_INSPECTIONS_ERROR_LOG;

    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in BRIDGE_INSPECTIONS_ERROR_LOG';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'IBRIDGES_DAILY_REFRESH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('BRIDGE_INSPECTIONS_ERROR_LOG',
                         'Invalid data - check error log',
                         g_jobname,
                         start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

    -- Check element inspections error log for quality errors

    SELECT COUNT (*)
      INTO errlog_count
      FROM wh_assets.ELEMENT_INSPECTION_ERROR_LOG;


    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in ELEMENT_INSPECTION_ERROR_LOG';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'IBRIDGES_DAILY_REFRESH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('ELEMENT_INSPECTION_ERROR_LOG',
                         'Invalid data - check error log',
                         g_jobname,
                         start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

    -- Check program history error log for quality errors

    SELECT COUNT (*)
      INTO errlog_count
      FROM wh_assets.program_history_error_log;


    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in PROGRAM_HISTORY_ERROR_LOG';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'IBRIDGES_DAILY_REFRESH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('PROGRAM_HISTORY_ERROR_LOG',
                         'Invalid data - check error log',
                         g_jobname,
                         start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

    -- Check workplan review error log for quality errors

    SELECT COUNT (*)
      INTO errlog_count
      FROM wh_assets.WORKPLAN_FIELDREV_ERROR_LOG;


    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in WORKPLAN_FIELDREV_ERROR_LOG';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'IBRIDGES_DAILY_REFRESH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('WORKPLAN_FIELDREV_ERROR_LOG',
                         'Invalid data - check error log',
                         g_jobname,
                         start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;
    
       -- Check retaining walls error log for quality errors

    SELECT COUNT (*)
      INTO errlog_count
      FROM wh_assets.RETAINING_WALLS_ERROR_LOG;


    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in RETAINING_WALLS_ERROR_LOG';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'IBRIDGES_DAILY_REFRESH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('RETAINING_WALLS_ERROR_LOG',
                         'Invalid data - check error log',
                         g_jobname,
                         start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;
    
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
            -20050,
            $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
END;
/
