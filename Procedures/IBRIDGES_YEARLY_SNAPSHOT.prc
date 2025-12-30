CREATE OR REPLACE PROCEDURE ibridges_yearly_snapshot
/********************************************************************************************************
This procedure creates the yearly snapshot of the ibridges table

It is run yearly on 3/1/yyyy (or at freeze time) to implement the yearly snapshot.

Each row that is current (end date is null) in the ibridges_history table is end-dated, and a new row is
inserted for the next year with a state = 'CURRENT'.

It looks up the new highway_id, section_id, and begin/end section offsets so must be run after the yearly
snapshot of the highways and roadway_sections tables.

When new columns are added to the ibridges_history table, they must be added to this procedure.


1-17-2017 - SH - Initial version

2-13-17 - SH Add column ABUT_TO_ABUT_DETOUR

02-17-17 SH - Add the metrans offset back in.  Needed to calculate the location of the bridge on primary/alternate routes - Ed Beckwith request
                 New column named milepoint will refer to the milepoint on the primary route and come from InspectTech
                 offset will refer to the offset of the bridge on the element and come from METrans
             add column milepoint to this procedure
03-17-17 SH - Add new columns from Over Limit Form
                 Jim Foster request
                 OL_PERMIT_LEFT_RAMP_FT, OL_PERMIT_LEFT_RAMP_IN,OL_PERMIT_OTHER_FT,
                 OL_PERMIT_OTHER_IN, OL_PERMIT_PORTAL_NORTH_FT, OL_PERMIT_PORTAL_NORTH_IN,
                 OL_PERMIT_PORTAL_SOUTH_FT, OL_PERMIT_PORTAL_SOUTH_IN,
                 OL_PERMIT_RIGHT_RAMP_FT, OL_PERMIT_RIGHT_RAMP_IN

04-12-17 SH - Add new columns:  last_element_inspection_date, last_routine_inspection_date
04-24-17 SH - Add new columns:  FIELD_REVIEW_DATE, FIELD_REVIEW_STATUS
5/15/17  SH  Add the most recent inspection of anytype, column: last_inspection_anytype
5-30-2017 SH - Add real sequence number
               Log procedure & function when other exceptions in data exceptions table
 5-31-2017 SH  Added procedure to lookup highway_id in cursor loop
               Used to create 2017 snapshot in factst
 05-01-18 SH  Add new columns:  PARENT_ASSET, year_last_painted,year_ws_replaced - Chester Kolota request
 08-28-18 SH  Add columns OL_NORTH_MAIN_POSTED, OL_NORTH_OTHER_POSTED, OL_NORTH_RAMP_POSTED, OL_PORTAL_NORTH_POSTED,
                          OL_PORTAL_SOUTH_POSTED, OL_SOUTH_MAIN_POSTED, OL_SOUTH_OTHER_POSTED, OL_SOUTH_RAMP_POSTED
 11-28-2018 SH - Modify to use highways_history instead of highways in preparation for going to full network
 02-06-2019 SH - Change highways_history to element_history, roadway_section_history to NEW_SECTIONS_HISTORY to use full network
 02-14-2019 SH - Change new_sections_history to sections_history
 03-05-2019 SH - Reviewed for yearly snapshot.  Posted_clearance is a new virtual column this year, but no changes needed to support it.
 03-25-2019 SH - Move version in wh_assets_dev to test
 06-04-2019 SH - End date old section outside of loop to avoid large rollback segment generation
 06-05-2019 SH - Get element_wid and section_id for rail, type_of_service_on = '2' as we now have the complete network
 12-03-2019 SH - Add columns related to underclearances: MIN_VERT_UNDER_REF_FEATURE, MIN_VERT_UNDER_REF_FEATURE_DESCR (NBI54A) requested by Jon Prendergast
 12-13-2019 SH - Add column MTRNS_ASSETNO to support bridge pointers for portal underclearances
 03-03-2020 SH - Reviewed for yearly snapshot,  add columns ARCHIVED_DATE, ARCHIVED_REASON
 03-13-2020 SH - Add more columns fron overlimit from LR_POSTED_DATE, OL_NORTH_MAIN_POSTED_FT,OL_NORTH_MAIN_POSTED_IN, OL_NORTH_OTHER_POSTED_FT, OL_NORTH_OTHER_POSTED_IN,OL_NORTH_RAMP_POSTED_FT,OL_NORTH_RAMP_POSTED_IN,OL_PORTAL_NORTH_POSTED_FT,
             OL_PORTAL_NORTH_POSTED_IN,OL_PORTAL_SOUTH_POSTED_FT,OL_PORTAL_SOUTH_POSTED_IN,OL_SOUTH_MAIN_POSTED_FT, OL_SOUTH_MAIN_POSTED_IN,OL_SOUTH_OTHER_POSTED_FT,OL_SOUTH_OTHER_POSTED_IN,OL_SOUTH_RAMP_POSTED_FT,OL_SOUTH_RAMP_POSTED_IN
             MTRNS_ASSETNO_LEFT_RAMP,MTRNS_ASSETNO_N_OR_E,MTRNS_ASSETNO_OTHER,MTRNS_ASSETNO_PORTAL_N_OR_E,MTRNS_ASSETNO_PORTAL_S_OR_W, MTRNS_ASSETNO_RIGHT_RAMP,MTRNS_ASSETNO_S_OR_W
 03-15-2020 SH - Moved to production
 04-04-2021 SH - Remove commit from fetch loop to avoid snapshot too old, rollback segment too small (ora-01555), 
               commit after all rows inserted
 01-26-2023 SH Add new columns LR_EV2_RATING, LR_EV3_RATING (JIRA DOTDW-758)  
       
******************************************************************************************************************/
IS
BEGIN
    DECLARE
        CURSOR all_bridges
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
                   archived_date,
                   archived_reason,
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
                   county,
                   county2,
                   county_name,
                   county2_name,
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
                   b.feature_under_structure,
                   federal_land_hwy,
                   federal_land_hwy_descr,
                   federal_sufficiency_rating,
                   field_review_date,
                   field_review_status,
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
                   inspection_type,
                   inspection_type_descr,
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
                   last_element_inspection_date,
                   last_inspection_anytype,
                   last_routine_inspection_date,
                   b.latitude,
                   length_max_span,
                   level_of_service_on,
                   level_of_service_on_descr,
                   location_description,
                   b.longitude,
                   lr_ev2_rating, 
                   lr_ev3_rating,
                   lr_posted_date,
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
                   mtrns_assetno,
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
                   offset,
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
                   OL_NORTH_MAIN_POSTED_FT,
                   OL_NORTH_MAIN_POSTED_IN,
                   ol_north_other_posted,
                   OL_NORTH_OTHER_POSTED_FT,
                   OL_NORTH_OTHER_POSTED_IN,
                   ol_north_ramp_posted,
                   OL_NORTH_RAMP_POSTED_FT,
                   OL_NORTH_RAMP_POSTED_IN,
                   ol_portal_north_posted,
                   OL_PORTAL_NORTH_POSTED_FT,
                   OL_PORTAL_NORTH_POSTED_IN,
                   ol_portal_south_posted,
                   OL_PORTAL_SOUTH_POSTED_FT,
                   OL_PORTAL_SOUTH_POSTED_IN,
                   ol_south_main_posted,
                   OL_SOUTH_MAIN_POSTED_FT,
                   OL_SOUTH_MAIN_POSTED_IN,
                   ol_south_other_posted,
                   OL_SOUTH_OTHER_POSTED_FT,
                   OL_SOUTH_OTHER_POSTED_IN,
                   ol_south_ramp_posted,
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
                   placecode,
                   placecode_descr,
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
                   towncode,
                   towncode2,
                   town_name1,
                   town_name2,
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
                   element_id_on_structure,
                   route_type_on_structure,
                   primary_route_number,
                   primary_route_name,
                   priority
              FROM ibridges_history b
             WHERE b.end_date IS NULL;



        rec                      all_bridges%ROWTYPE;
        common_run_date          DATE := SYSDATE;
        current_year             NUMBER;
        last_snapshot_year       NUMBER;
        cntr                     NUMBER := 0;
        cntr_updated             NUMBER := 0;
        cntr_added               NUMBER := 0;
        G_owner                  VARCHAR2 (20) := 'WH_ASSETS';
        G_jobname                VARCHAR2 (30) := $$PLSQL_UNIT;
        g_start_time             DATE := SYSDATE;
        g_object                 VARCHAR2 (21) := 'IBRIDGES_YRLY_SNAP';
        G_SQLMSG                 VARCHAR2 (1000) := NULL;
        V_flat_file_counts_txt   VARCHAR2 (1000) := NULL;
        errlog_count             NUMBER;
        err_log_message          VARCHAR2 (200) := NULL;

        sect_id                  NUMBER;
        bsection_offset          NUMBER;
        esection_offset          NUMBER;
        thighway_id              NUMBER;

        FUNCTION Get_Element_wid (ele_id IN NUMBER)
            RETURN NUMBER
        IS
            hiway_id   NUMBER;
            err        VARCHAR2 (100);
        BEGIN
            SELECT h.element_wid
              INTO hiway_id
              FROM element_history h
             WHERE h.end_date IS NULL AND ele_id = h.element_id;

            RETURN hiway_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                err :=
                    'element_id associated with a bridge road not in highways view';

                INSERT INTO data_exceptions (TABLE_NAME,
                                             ERROR_CONDITION,
                                             TEST_PROCEDURE,
                                             TEST_DATE,
                                             ASSESSMENT,
                                             COLUMN_NAME1,
                                             COLUMN_VALUE1,
                                             COLUMN_NAME2,
                                             COLUMN_VALUE2)
                     VALUES (g_object,
                             err,
                             g_jobname,
                             common_run_date,
                             'EXCEPTION',
                             'FUNCTION',
                             'GET_HIGHWY_ID',
                             'ELEMENT_ID',
                             ele_id);

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
                     VALUES (g_object,
                             err,
                             g_jobname,
                             common_run_date,
                             'EXCEPTION',
                             'FUNCTION',
                             'GET_HIGHWY_ID',
                             'ELEMENT_ID',
                             ele_id);

                RETURN NULL;
        END;


        PROCEDURE Get_section_id (brdg_no        IN     VARCHAR,
                                  el_id          IN     NUMBER,
                                  brdg_offst     IN     NUMBER,
                                  bsect_offset      OUT NUMBER,
                                  esect_offset      OUT NUMBER,
                                  sec_id            OUT NUMBER)
        IS
            -- Gets the section id, begin/end section offsets from the sections table
            -- using the element id/ bridge offset from metrans
            counter   NUMBER;
            err       VARCHAR2 (100);
        BEGIN
            counter := 0;

            SELECT COUNT (*) -- determine if offset lies on a section boundary
              INTO counter
              FROM sections_history s
             WHERE     el_id = s.element_id
                   AND s.state = 'CURRENT'
                   AND ROUND (brdg_offst, 2) >= s.begin_offset
                   AND ROUND (brdg_offst, 2) <= S.end_offset;

            IF counter = 1                        -- not on a section boundary
            THEN
                SELECT s.section_id, s.begin_offset, s.end_offset
                  INTO sec_id, bsect_offset, esect_offset
                  FROM sections_history s
                 WHERE     el_id = s.element_id
                       AND s.state = 'CURRENT'
                       AND ROUND (brdg_offst, 2) >= s.begin_offset
                       AND ROUND (brdg_offst, 2) <= s.end_offset;
            END IF;

            IF counter > 1 -- on a section boundary, round to match the tide bridge table, the second section is chosen
            THEN
                SELECT s.section_id, s.begin_offset, s.end_offset
                  INTO sec_id, bsect_offset, esect_offset
                  FROM sections_history s
                 WHERE     el_id = s.element_id
                       AND s.state = 'CURRENT'
                       AND ROUND (brdg_offst, 2) >= S.BEGIN_OFFSET
                       AND ROUND (brdg_offst, 2) < S.END_OFFSET;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                err := 'No section ID for bridge with element id : ';

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
                     VALUES ('ibridges_history',
                             err,
                             $$PLSQL_UNIT,
                             common_run_date,
                             'NO DATA FOUND',
                             'BRIDGE_NUMBER',
                             brdg_no,
                             'ELEMENT_ID',
                             el_id,
                             'BRIDGE OFFSET',
                             brdg_offst);
            WHEN OTHERS
            THEN
                err :=
                       'Error num :'
                    || TO_CHAR (SQLCODE)
                    || ' '
                    || SUBSTR (SQLERRM, 1, 100);

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
                     VALUES ('ibridges_history',
                             err,
                             $$PLSQL_UNIT,
                             common_run_date,
                             'NO DATA FOUND',
                             'BRIDGE_NUMBER',
                             brdg_no,
                             'ELEMENT_ID',
                             el_id,
                             'BRIDGE OFFSET',
                             brdg_offst);
        END;

        PROCEDURE insert_duplicate_row
        IS
        BEGIN
            INSERT INTO ibridges_history (bridge_id,
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
                                          archived_date,
                                          archived_reason,
                                          asset_status,
                                          asset_status_descr,
                                          asset_type,
                                          begin_section_offset,
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
                                          county,
                                          county2,
                                          county_name,
                                          county2_name,
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
                                          element_id_on_structure,
                                          end_section_offset,
                                          fc_inspection_required,
                                          fc_inspection_frequency,
                                          fc_last_inspection,
                                          feature_on_structure,
                                          feature_under_structure,
                                          federal_land_hwy,
                                          federal_land_hwy_descr,
                                          federal_sufficiency_rating,
                                          field_review_date,
                                          field_review_status,
                                          fips_region,
                                          fips_region_descr,
                                          fips_state_code,
                                          fips_state_code_desc,
                                          funding_eligibility,
                                          geographic_region,
                                          geographic_region_descr,
                                          highway_id_on_structure,
                                          historical_significance,
                                          historical_significance_descr,
                                          horizontal_clearance,
                                          inspection_date,
                                          inspection_frequency,
                                          inspection_type,
                                          inspection_type_descr,
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
                                          last_element_inspection_date,
                                          last_inspection_anytype,
                                          last_routine_inspection_date,
                                          latitude,
                                          length_max_span,
                                          level_of_service_on,
                                          level_of_service_on_descr,
                                          location_description,
                                          longitude,
                                          lr_ev2_rating, 
                                          lr_ev3_rating,
                                          lr_posted_date,
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
                                          mtrns_assetno,
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
                                          offset,
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
                                          OL_NORTH_MAIN_POSTED_FT,
                                          OL_NORTH_MAIN_POSTED_IN,
                                          ol_north_other_posted,
                                          OL_NORTH_OTHER_POSTED_FT,
                                          OL_NORTH_OTHER_POSTED_IN,
                                          ol_north_ramp_posted,
                                          OL_NORTH_RAMP_POSTED_FT,
                                          OL_NORTH_RAMP_POSTED_IN,
                                          ol_portal_north_posted,
                                          OL_PORTAL_NORTH_POSTED_FT,
                                          OL_PORTAL_NORTH_POSTED_IN,
                                          ol_portal_south_posted,
                                          OL_PORTAL_SOUTH_POSTED_FT,
                                          OL_PORTAL_SOUTH_POSTED_IN,
                                          ol_south_main_posted,
                                          OL_SOUTH_MAIN_POSTED_FT,
                                          OL_SOUTH_MAIN_POSTED_IN,
                                          ol_south_other_posted,
                                          OL_SOUTH_OTHER_POSTED_FT,
                                          OL_SOUTH_OTHER_POSTED_IN,
                                          ol_south_ramp_posted,
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
                                          placecode,
                                          placecode_descr,
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
                                          primary_route_name,
                                          primary_route_number,
                                          priority,
                                          rail_rating,
                                          rail_rating_descr,
                                          remaining_service_life,
                                          ROUTE_TYPE_ON_STRUCTURE,
                                          score_date,
                                          scour_rating,
                                          scour_rating_descr,
                                          section_id,
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
                                          towncode,
                                          towncode2,
                                          town_name1,
                                          town_name2,
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
                 VALUES (assets_sequence.NEXTVAL,
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
                         rec.archived_date,
                         rec.archived_reason,
                         rec.asset_status,
                         rec.asset_status_descr,
                         rec.asset_type,
                         bsection_offset,
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
                         rec.county,
                         rec.county2,
                         rec.county_name,
                         rec.county2_name,
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
                         rec.element_id_on_structure,
                         esection_offset,
                         rec.fc_inspection_required,
                         rec.fc_inspection_frequency,
                         rec.fc_last_inspection,
                         rec.feature_on_structure,
                         rec.feature_under_structure,
                         rec.federal_land_hwy,
                         rec.federal_land_hwy_descr,
                         rec.federal_sufficiency_rating,
                         rec.field_review_date,
                         rec.field_review_status,
                         rec.fips_region,
                         rec.fips_region_descr,
                         rec.fips_state_code,
                         rec.fips_state_code_desc,
                         rec.funding_eligibility,
                         rec.geographic_region,
                         rec.geographic_region_descr,
                         thighway_id,
                         rec.historical_significance,
                         rec.historical_significance_descr,
                         rec.horizontal_clearance,
                         rec.inspection_date,
                         rec.inspection_frequency,
                         rec.inspection_type,
                         rec.inspection_type_descr,
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
                         rec.last_element_inspection_date,
                         rec.last_inspection_anytype,
                         rec.last_routine_inspection_date,
                         rec.latitude,
                         rec.length_max_span,
                         rec.level_of_service_on,
                         rec.level_of_service_on_descr,
                         rec.location_description,
                         rec.longitude,
                         rec.lr_ev2_rating, 
                         rec.lr_ev3_rating,
                         rec.lr_posted_date,
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
                         rec.mtrns_assetno,
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
                         rec.offset,
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
                         rec.OL_NORTH_MAIN_POSTED_FT,
                         rec.OL_NORTH_MAIN_POSTED_IN,
                         rec.ol_north_other_posted,
                         rec.OL_NORTH_OTHER_POSTED_FT,
                         rec.OL_NORTH_OTHER_POSTED_IN,
                         rec.ol_north_ramp_posted,
                         rec.OL_NORTH_RAMP_POSTED_FT,
                         rec.OL_NORTH_RAMP_POSTED_IN,
                         rec.ol_portal_north_posted,
                         rec.OL_PORTAL_NORTH_POSTED_FT,
                         rec.OL_PORTAL_NORTH_POSTED_IN,
                         rec.ol_portal_south_posted,
                         rec.OL_PORTAL_SOUTH_POSTED_FT,
                         rec.OL_PORTAL_SOUTH_POSTED_IN,
                         rec.ol_south_main_posted,
                         rec.OL_SOUTH_MAIN_POSTED_FT,
                         rec.OL_SOUTH_MAIN_POSTED_IN,
                         rec.ol_south_other_posted,
                         rec.OL_SOUTH_OTHER_POSTED_FT,
                         rec.OL_SOUTH_OTHER_POSTED_IN,
                         rec.ol_south_ramp_posted,
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
                         rec.placecode,
                         rec.placecode_descr,
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
                         rec.primary_route_name,
                         rec.primary_route_number,
                         rec.priority,
                         rec.rail_rating,
                         rec.rail_rating_descr,
                         rec.remaining_service_life,
                         rec.ROUTE_TYPE_ON_STRUCTURE,
                         rec.score_date,
                         rec.scour_rating,
                         rec.scour_rating_descr,
                         sect_id,
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
                         rec.towncode,
                         rec.towncode2,
                         rec.town_name1,
                         rec.town_name2,
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
                         common_run_date                    /* date_created */
                                        ,
                         NULL                                /*date_modified*/
                             ,
                         'IBRIDGES_YEARLY_SNAPSHOT'             /*created_by*/
                                                   ,
                         NULL                                   /* end_date */
                             ,
                         NULL                                /* modified_by */
                             ,
                         current_year                        /*snapshot_year*/
                                     ,
                         common_run_date                        /*start_date*/
                                        ,
                         'CURRENT'                                   /*state*/
                                  )
                    LOG ERRORS INTO IBRIDGES_HISTORY_ERROR_LOG
                            ('IBRIDGES YEARLY SNAPSHOT ' || SYSDATE)
                            REJECT LIMIT 100;

        END;
    BEGIN
        SELECT MAX (snapshot_year)
          INTO last_snapshot_year
          FROM ibridges_history;

        current_year := last_snapshot_year + 1;


        EXECUTE IMMEDIATE 'TRUNCATE TABLE ibridges_history_error_log';

        OPEN all_bridges;

        LOOP
            FETCH all_bridges INTO rec;

            EXIT WHEN all_bridges%NOTFOUND;


            -- Get Section ID for new snapshot year and begin/end offsets of section
            sect_id := NULL;
            bsection_offset := NULL;
            esection_offset := NULL;
            thighway_id := NULL;

            IF     (   rec.type_of_service_on IN ('1',
                                                  '2',                 -- rail
                                                  '4',
                                                  '5',
                                                  '6') -- highway, highway-railroad, highway-pedestrian, overpass
                    OR rec.route_type_on_structure = 'HIGHWAY') -- handles the case of missing type_of_service_on
               AND rec.element_id_on_structure IS NOT NULL
            THEN
                thighway_id := Get_element_wid (rec.element_id_on_structure);
                Get_section_id (rec.bridge_number,
                                rec.element_id_on_structure,
                                rec.offset,
                                bsection_offset,
                                esection_offset,
                                sect_id);
            END IF;

            -- Insert new row
            cntr_added := cntr_added + 1;
            Insert_duplicate_row;
        END LOOP;

        CLOSE all_bridges;


        COMMIT;

        -- Set counter updated for reporting

        SELECT COUNT (*)
          INTO cntr_updated
          FROM ibridges_history
         WHERE snapshot_year = last_snapshot_year AND end_date IS NULL;


        -- End date old bridge


        UPDATE ibridges_history
           SET end_date = common_run_date,
               date_modified = common_run_date,
               modified_by = 'YEARLY_SNAPSHOT',
               state = 'PAST'
         WHERE snapshot_year = last_snapshot_year AND end_date IS NULL;


        COMMIT;

        SELECT COUNT (*) INTO errlog_count FROM ibridges_history_error_log;

        IF errlog_count > 0
        THEN
            BEGIN
                err_log_message :=
                    'Unexpected Data Quality Issues in ibridges error log ';

                INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                                ERR_MODULE,
                                                ERR_OID,
                                                ERR_MESSAGE)
                     VALUES (SYSDATE,
                             'IBRIDGES_YEARLY_SNAPSHOT',
                             'WH_ASSETS',
                             err_log_message);

                COMMIT;
                wh_common.pkg_common_utilities.exit_and_report (
                    $$PLSQL_UNIT,
                    'FAILURE',
                    err_log_message);
                RAISE_APPLICATION_ERROR (
                    -20010,
                    $$PLSQL_UNIT || ' ' || err_log_message);
            END;
        ELSE                                                 -- Successful Run
            BEGIN
                SELECT COUNT (*) INTO cntr FROM ibridges_history;

                WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
                    OWNER         => G_OWNER,
                    OBJECT_NAME   => g_object,
                    object_cnt    => cntr,
                    add_cnt       => cntr_added,
                    update_cnt    => cntr_updated,
                    proc          => $$PLSQL_UNIT,
                    start_time    => g_start_time);

                WH_COMMON.PKG_COMMON_UTILITIES.EXIT_AND_REPORT (
                    g_jobname,
                    'NORMAL',
                    V_flat_file_counts_txt);
            END;
        END IF;
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
            RAISE_APPLICATION_ERROR (-20010, $$PLSQL_UNIT || ' ' || G_SQLMSG);
    END;
END;
/
