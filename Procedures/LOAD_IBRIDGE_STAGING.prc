CREATE OR REPLACE PROCEDURE load_ibridge_staging
IS
   /**********************************************************************
   This procedure loads the ibridges staging table with data from InspecTech for
   the weekly and daily refresh processes.
   
     It reads the data from EXT_BRIDGES, EXT_BRIDGES2, ext_lpr external tables
   It is invoked from the procedures, ibridges_daily_refresh and ibridges_weekend_refresh


   Modification History:

   9/3/14 - SH - Added check for 99.9 for operating_rating & inventory_rating
   so it will not be converted from metric to english
   3/2/15 - SH - Added creation_date for logging changes purposes
   5/29/15 SH - Remove lookup of segment_id of the bridge from TIDE.  Moved into Load_bridges_from_metrans
   to calculate it based on the element_id and offset
   - Remove code to get the columns from the Pontis Roadway Table describing the road under the structure as this is now
   done in load_bridge_roads_staging procedure
   6/18/2015 SH - Convert truck_weight_post_limit from metric to english
   6/23/2015 - SH - Add maintenance region description instead of getting it from pontis
   to avoid some data quality issues
   7/7/15 SH - Look up maintenance region description from wh_common.dim_maint_regions
   07/10/15 SH - Remove ltrim from county code to retain leading zero
   9/30/2015 SH - Drop columns not needed in staging table, and remove from update statement
                  Date_created, start_date, created_by
                  Modified_by, Date_modified, end_date
   6-9-16 SH Modify cursor to fix bug not picking up bridges with blank towns
             Add new columns from JP, bridge_group, nbis_inspection_done, underwater_inspection_done
   6-13-16 SH Add calculation for remaining service life
   6-13-16  SH  Initial Version copied from load_bridges_staging for Inspect Tech data,
   6-17-2016 SH Modify for daily refresh of inspect tech data and weekly refresh of all other data
                Update staging table with Inspect Tech Data rather than re-create it during the week
                Recreate staging table on the weekends
                Rename to load_ibridge_staging

   6-23-2016 SH  Add second external table to accomodate new columns from JP,
                 Min_lat_under_clear_left, Min_lat_under_clear_right
                 Add standard error handling
   6-28-2016 SH  Add columns co_owner, co_maintainer for dim_bridges (P. Devlin),
                 userbrdg_owner, userbrdg_mainter for JP along with their descriptions
                 Modify description lookups to eliminate the need to know fe_id
   6-29-2016 SH - fix problems discovered with testing
                  MIN_VERTICAL_CLEARANCE_ON  Dont convert missing data
   6-30-2016 SH - Remove conversion of   Min_lat_under_clear_left, Min_lat_under_clear_right from metric to english,
                  already done in Inspect Tech
                  Check year_reconstructed = -1 or -4 after conversion to number/set to 0
   7-11-2016 SH - Remove trailing space from userbrdg_owner
   7-25-2016 SH - Add additional columns from Cindy Owings - CLEAR_SPAN_LENGTH, DECK_PROTECTION_CODE,
                  DECK_PROTECTION_DESCR, MAIN_SPAN_NUMBER, MINOR_SPAN_CODE_DESCR (subcategory), NEIGHBOR_STATE_CODE_DESCR
   8-8-2016 SH - Remove conversion of metric to english units for operating_rating and inventory_rating per Cindy Owings
   'not all of the numbers in the inventory rating and operating rating numbers are of the same unit. Some are actual factors.'
   8-9-2016 SH - Add new columns from Cindy Owings - BRIDGE_POSTING, BRIDGE_POSTING_DESCR, BORDER_BRIDGE_PERCENT_RESP,
                BORDER_BRIDGE_NUMBER, CURB_SIDEWALK_WIDTH_LEFT, CURB_SIDEWALK_WIDTH_RIGHT,FEDERAL_LAND_HWY, FEDERAL_LAND_HWY_DESCR,
                HISTORICAL_SIGNIFICANCE, HISTORICAL_SIGNIFICANCE_DESCR, MIN_NAVCLR_LIFT_BRDG, NAVIGATION_CONTROL, NAVIGATION_CONTROL_DESCR,
                ON_BASE_HIGHWAY_NETWORK, ON_BASE_HIGHWAY_NETWORK_DESCR, PARALLEL_STRUCTURE_DESIG, PARALLEL_STRUCTURE_DESIG_DESCR,
                STATUS, STATUS_DESCR, TEMP_STUCTURE_DESIG, TEMP_STRUCTURE_DESIG_DESCR
   8-10-16 SH - Cleanse VEHICLE_HEIGHT_OVER, Set to 99.99 (NBI 53) indicating no superstructure restriction exists above the bridge roadway,
   or when a restriction is 30 meters or greater, it is indicated as 99.99.  InspecTech converted meters to feet, in error.
   8-11-16 SH - Redesign lookup of descriptions
   8-26-2016 SH - Add new columns requested by Cindy Owings - asset_type, invrte_adt, invrte_adt_truck_percent, invrte_adt_yr,  invrte_dirsuffix,invrte_dirsuffix_descr, invrte_functionclass,             
                  invrte_functionclass_descr,invrte_on_nhs, invrte_on_nhs_descr,  invrte_lrs_rtenum,  invrte_lrs_subrtenum,  invrte_rectype,invrte_rtenum,  invrte_on_strahnet,invrte_on_strahnet_descr,              
                 invrte_on_trucknet, invrte_on _trucknet_descr, number_lanes_under           
   8-29-2016 SH - strip extra space off end of invrte_rtenum when converting it to a number
   9-7-16 SH - Add columns from special bridge_inspections   FC_INSPECTION_REQUIRED, FC_INSPECTION_FREQUENCY, FC_LAST_INSPECTION              
                                                             SI_INSPECTION_REQUIRED, SI_INSPECTION_FREQUENCY, SI_LAST_INSPECTION              
                                                             UW_INSPECTION_REQUIRED, UW_INSPECTION_FREQUENCY, UW_LAST_INSPECTION    
              Replace offset from metrans with milepoint (on primary route) from Inspectech (Cindy Owings request)          
   9-8-16 SH - Modify cursor to get special inspections from external table, EXT_BRIDGES2 (cleanup)
   9-19-16 SH - Modified quote character to brackets [] when exporting data from sql server bcp command file
                to account for change in bridge name which included quotes - Captain John "Jay" ... increased bridge name to 75 chars
   9-26-16 SH - Set underwater_inspection_done to 1 if uw_last_inspection from inspecTech is not null as Old Pontis field not being updated in InspecTech
   10-13-16 SH - Add Posting data from the load-rating form and 5 axle cranes, 5 axle cranes with dolly POSTED, POSTED_WEIGHT_TONS, POSTED_1_TRUCK,  
                 POSTED_4_AXLE, POSTED_SPACING, POSTED_5AXLE_CRANE, POSTED_5AXLE_CRANE_DOLLY  
                 
   11-21-16 SH - Add columns from Overlimit Form describing Vertical Clearance  OL_NORTH_RIGHT_RAMP_FT, OL_NORTH_RIGHT_RAMP_IN, OL_PERMIT_SOUTH_FT, OL_PERMIT_SOUTH_IN 
                 OL_PERMIT_NORTH_FT, OL_PERMIT_NORTH_IN (JP Request)
   12-6-16 SH - split refresh into ibridges_daily_refresh and ibridges_weekend_refresh to fix problem where new bridge could only be added on the weekend   
              - get latitude/longitude from InspectTech rather than Metrans, remove from load_ibridges_staging_location 
   12-9-16 SH - add posting and ratings columns that can be updated via a from independent of an inspection
       APP_GUARDRAIL_END_RATING,  APP_GUARDRAIL_END_RATING_DESCR, APP_GUARDRAIL_RATING, APP_GUARDRAIL_RATING_DESCR, APP_ROAD_ALIGN_RATING,
       APP_ROAD_ALIGN_RATING_DESCR, DECK_GEOMETRY_RATING, DECK_GEOMETRY_RATING_DESCR, PIER_PROTECTION_RATING, PIER_PROTECTION_RATING_DESCR,
       STRUCTURAL_EVALUATION, STRUCTURAL_EVALUATION_DESCR,STRUCTURE_OPEN, STRUCTURE_OPEN_DESCR, UNDERCLEARANCE_RATING, UNDERCLEARANCE_RATING_DESCR    
   12-19-16 SH - Add minus(-) sign in front of longitude when inserting new row if it is not there for consistency    
   12-20-16 SH - Replace blank with NULL for the ratings columns (Cindy Owings request) 
                  APP_GUARDRAIL_END_RATING, APP_GUARDRAIL_RATING, APP_ROAD_ALIGN_RATING, CHANNEL_RATING, CULVERT_RATING, DECK_GEOMETRY_RATING,
                  DECK_RATING,PIER_PROTECTION_RATING,RAIL_RATING,SCOUR_RATING,SUBSTRUCTURE_RATING,SUPERSTRUCTURE_RATING,TRANSITION_RATING,
                  UNDERCLEARANCE_RATING, WATERWAY_ADEQUACY_RATING
                - Add columns ASSET_STATUS, ASSET_STATUS_DESCR from InspecTech to indicate if a bridge has been archived or is in-service  
   12-21-16 SH - Add column INSPECTION_FREQUENCY
   02-02-16 SH - Add column ABUT_TO_ABUT_DETOUR (Chester Kolota request)
   02-17-17 SH - Add the metrans offset back in.  Needed to calculate the location of the bridge on primary/alternate routes - Ed Beckwith request
                 New column named milepoint will refer to the milepoint on the primary route and come from InspectTech
                 offset will refer to the offset of the bridge on the element and come from METrans
                 In the procedure references to offset will be changed to milepoint.  The offset is added in load_ibridges_staging_location
   02-28-17 SH - Round clear_span_length
   03-17-17 SH - Add new columns from Over Limit from 
                 Jim Foster request
                 OL_PERMIT_LEFT_RAMP_FT, OL_PERMIT_LEFT_RAMP_IN,OL_PERMIT_OTHER_FT, 
                 OL_PERMIT_OTHER_IN, OL_PERMIT_PORTAL_NORTH_FT, OL_PERMIT_PORTAL_NORTH_IN, 
                 OL_PERMIT_PORTAL_SOUTH_FT, OL_PERMIT_PORTAL_SOUTH_IN,
                 OL_PERMIT_RIGHT_RAMP_FT, OL_PERMIT_RIGHT_RAMP_IN
    03-21-17 SH  Set type_of_service_on to empty string if type_of_service_on is null so null values will not be eliminated from query (Tom Farwell)
    4/27/17 SH Log procedure & function when other exceptions in data exceptions table
    06-05-2017 SH Bring im the rail bridges (modify cursor)
    06-07-17 SH Remove inspection type and inspection type description.  Source for these is bridge inspection data. 
    06-08-17 SH  Add check of ibridges_staging_error_log for invalid data written there
    04-30-18 SH  Add new columns:  PARENT_ASSET, year_last_painted,year_ws_replaced - Chester Kolota request
    06-25-18 SH  Get maintenance region description from dim_regions instead of dim_maint_regions which is going away. Concatenate an 8 to the
                 beginning of the region code for this table, ie.  region 1 is region 81.
    08-28-18 SH  Add columns OL_NORTH_MAIN_POSTED, OL_NORTH_OTHER_POSTED, OL_NORTH_RAMP_POSTED, OL_PORTAL_NORTH_POSTED, 
                             OL_PORTAL_SOUTH_POSTED, OL_SOUTH_MAIN_POSTED, OL_SOUTH_OTHER_POSTED, OL_SOUTH_RAMP_POSTED     
    10-08-18 SH  Move to Production
    10-15-18 SH  Change lookup of 'GEOGRAPHIC_REGION' to 'MAINTENANCE_REGION' to correspond with changes to BRIDGE_MAPPINGS table.
                 Corresponds to this change - Thecorrect Inspecttech field for Maintenance Region Code is NBI 002 with FE_ID: 2000200. 
    The Bridge subject areas that have this field mapped to FE_ID: 6000669 should be changed as this is the old Pontis field that is inactive  
    12-03-19 SH Add columns related to underclearances: MIN_VERT_UNDER_REF_FEATURE, MIN_VERT_UNDER_REF_FEATURE_DESCR (NBI54A) requested by Jon Prendergast       
    03-09-20 SH Add columns from ext_ol2 (more overlimit columns)     LR_POSTED_DATE, OL_NORTH_MAIN_POSTED_FT,OL_NORTH_MAIN_POSTED_IN,   OL_NORTH_OTHER_POSTED_FT,
                   OL_NORTH_OTHER_POSTED_IN,OL_NORTH_RAMP_POSTED_FT,OL_NORTH_RAMP_POSTED_IN,OL_PORTAL_NORTH_POSTED_FT,
                   OL_PORTAL_NORTH_POSTED_IN,OL_PORTAL_SOUTH_POSTED_FT,OL_PORTAL_SOUTH_POSTED_IN,OL_SOUTH_MAIN_POSTED_FT,
                   OL_SOUTH_MAIN_POSTED_IN,OL_SOUTH_OTHER_POSTED_FT,OL_SOUTH_OTHER_POSTED_IN,OL_SOUTH_RAMP_POSTED_FT,OL_SOUTH_RAMP_POSTED_IN,
    03-10-20 SH Add bridge pointer columns  MTRNS_ASSETNO_LEFT_RAMP,MTRNS_ASSETNO_N_OR_E,MTRNS_ASSETNO_OTHER,MTRNS_ASSETNO_PORTAL_N_OR_E,MTRNS_ASSETNO_PORTAL_S_OR_W,
                  MTRNS_ASSETNO_RIGHT_RAMP,MTRNS_ASSETNO_S_OR_W,
    04-05-21 SH Fix problem reported by Chester Kolata where posted_weight (in tons) -1 due to blank data in column
                Add check to convert value to null.  Added this check to other numeric columns
    06-28-21 SH Support for combining the extract of the highway and rail bridges extract from Assetwise by removing the UNION in the CURSOR to the rail bridges external tables 
                Set the maintenance region description to null when there is no maintenance region code (some of the rail bridges)
    09-15-22 SH strip extra character off end of parent_asset (Jerry Casey reported issue)
    01-26-23 SH Add new columns LR_EV2_RATING, LR_EV3_RATING (JIRA DOTDW-758)
    11-05-25 DG DOTDW-1090 Send alert if ASCII(0) found for inspection date, caused by approving date in SNBI in AssetWise,
                set date to NULL do not discard record or add row to TBERRLOG
   **********************************************************************/

   common_rundate                     DATE := SYSDATE;
   cntr                               NUMBER;
   surrogate_key                      NUMBER;
   procname                           VARCHAR2 (50) := 'LOAD_IBRIDGE_STAGING';
   num                                NUMBER;
   day_of_week                        VARCHAR2 (3) ;
   field_num                          NUMBER;
   errlog_count                       NUMBER;
   err_log_message                    VARCHAR2 (200) ;
   -- Temporary variables for columns to be converted to numeric
   tabut_to_abut_detour               NUMBER;
   tapproach_roadway_width            NUMBER;
   tapproach_span_number              NUMBER;
   tasset_status                      NUMBER;
   tborder_bridge_percent_resp        NUMBER;
   tbridge_length                     NUMBER;
   tclear_span_length                 NUMBER;
   tcurb_sidewalk_width_left          NUMBER;
   tcurb_sidewalk_width_right         NUMBER;
   tdeck_area                         NUMBER;
   tdetour_length                     NUMBER;
   tfederal_sufficiency_rating        NUMBER;
   thorizontal_clearance              NUMBER;
   tinspection_frequency              NUMBER;
   tinventory_rating                  NUMBER;
   tInvrte_Adt                        NUMBER;
   tInvrte_Adt_truck_percent          NUMBER;
   tInvrte_Adt_yr                     NUMBER;
   tInvrte_dirsuffix                  NUMBER;
   tInvrte_functionclass              NUMBER;
   tinvrte_on_nhs                     NUMBER;
   tInvrte_On_trucknet                NUMBER;
   tInvrte_On_strahnet                NUMBER;
   tInvrte_rtenum                     NUMBER;
   tlength_max_span                   NUMBER;
   tlr_ev2_rating                     NUMBER;
   tlr_ev3_rating                     NUMBER;
   tmain_span_number                  NUMBER;
   tmin_lat_under_clear_left          NUMBER;
   tmin_lat_under_clear_right         NUMBER;
   tmin_navclr_lift_brdg              NUMBER;
   tmin_vertical_clearance_on         NUMBER;
   tmin_vertical_under_clearance      NUMBER;
   tnavigation_horizontal             NUMBER;
   tnavigation_vertical               NUMBER;
   tnumber_lanes                      NUMBER;
   tNumber_lanes_under                NUMBER;
   tmilepoint                         NUMBER;
   tol_north_right_ramp_ft  NUMBER;
   tol_north_right_ramp_in  NUMBER;
   tol_permit_south_ft  NUMBER;
   tol_permit_south_in   NUMBER;
   tol_permit_north_ft  NUMBER;
   tol_permit_north_in  NUMBER;
   
   TOL_PERMIT_LEFT_RAMP_FT NUMBER;
   TOL_PERMIT_LEFT_RAMP_IN NUMBER;
  
   TOL_PERMIT_OTHER_FT NUMBER; 
   TOL_PERMIT_OTHER_IN NUMBER;
   TOL_PERMIT_PORTAL_NORTH_FT NUMBER;
   TOL_PERMIT_PORTAL_NORTH_IN NUMBER; 
   TOL_PERMIT_PORTAL_SOUTH_FT NUMBER;
   TOL_PERMIT_PORTAL_SOUTH_IN NUMBER;
   TOL_PERMIT_RIGHT_RAMP_FT NUMBER;
   TOL_PERMIT_RIGHT_RAMP_IN NUMBER;
   
    TLR_POSTED_DATE DATE;
    TOL_NORTH_MAIN_POSTED_FT NUMBER; 
    TOL_NORTH_MAIN_POSTED_IN NUMBER; 
    TOL_NORTH_OTHER_POSTED_FT  NUMBER; 
    TOL_NORTH_OTHER_POSTED_IN NUMBER; 
    TOL_NORTH_RAMP_POSTED_FT NUMBER; 
    TOL_NORTH_RAMP_POSTED_IN NUMBER; 
    TOL_PORTAL_NORTH_POSTED_FT NUMBER; 
    TOL_PORTAL_NORTH_POSTED_IN NUMBER; 
    TOL_PORTAL_SOUTH_POSTED_FT NUMBER; 
    TOL_PORTAL_SOUTH_POSTED_IN NUMBER; 
    TOL_SOUTH_MAIN_POSTED_FT NUMBER; 
    TOL_SOUTH_MAIN_POSTED_IN NUMBER; 
    TOL_SOUTH_OTHER_POSTED_FT NUMBER; 
    TOL_SOUTH_OTHER_POSTED_IN NUMBER; 
    TOL_SOUTH_RAMP_POSTED_FT NUMBER; 
    TOL_SOUTH_RAMP_POSTED_IN NUMBER; 


   
   toperating_rating                  NUMBER;
   tposted_weight_tons                NUMBER;
   trsl                               NUMBER;
   tskew_angle                        NUMBER;
   ttruck_weight_post_limit           NUMBER;
   tvehicle_height_over               NUMBER;
   tvehicle_height_under              NUMBER;
   tvehicle_load_limit                NUMBER;
   twidth                             NUMBER;
   twidth_curb_to_curb                NUMBER;
   tyear_built                        NUMBER;
   tyear_reconstructed                NUMBER;
 
   -- Temporary Variables to lookup descriptions

   descrip_len                        NUMBER;

   appspan_design_description         ibridges_staging.approach_span_design_descr%TYPE;
   appspan_material_description       ibridges_staging.approach_span_material_descr%TYPE;
   bridge_median_description          ibridges_staging.bridge_median_descr%TYPE;
   bridge_on_off_sys_description      ibridges_staging.bridge_on_off_system_descr%TYPE;
   bridge_posting_description         ibridges_staging.bridge_posting_descr%TYPE;
   channel_rating_description         ibridges_staging.channel_rating_descr%TYPE;
   co_maintainer_description          ibridges_staging.co_maintainer_descr%TYPE;
   co_owner_description               ibridges_staging.co_owner_descr%TYPE;
   culvert_rating_description         ibridges_staging.culvert_rating_descr%TYPE;
   deck_membrane_type_description     ibridges_staging.deck_membrane_type_descr%TYPE;
   deck_protection_description        ibridges_staging.deck_protection_descr%TYPE;
   deck_rating_description            ibridges_staging.deck_rating_descr%TYPE;
   deck_struct_type_description       ibridges_staging.deck_structure_type_descr%TYPE;
   deck_surface_type_description      ibridges_staging.deck_surface_type_descr%TYPE;
   design_load_description            ibridges_staging.design_load_descr%TYPE;
   federal_land_hwy_description       ibridges_staging.federal_land_hwy_descr%TYPE;
   geo_region_description             ibridges_staging.geographic_region_descr%TYPE;
   historical_sig_description         ibridges_staging.historical_significance_descR%TYPE;

   inv_rating_type_description        ibridges_staging.inventory_rating_type_descr%TYPE;
   invrte_dirsuffix_description       ibridges_staging.invrte_dirsuffix_descr%TYPE;
   dinvrte_functionclass_descr        ibridges_staging.invrte_functionclass_descr%TYPE;
   invrte_on_nhs_description          ibridges_staging.invrte_on_nhs_descr%TYPE;
   invrte_on_strahnet_description     ibridges_staging.invrte_on_strahnet_descr%TYPE;
   invrte_on_trucknet_description     ibridges_staging.invrte_on_trucknet_descr%TYPE;
   kind_of_highway_on_description     ibridges_staging.kind_of_highway_on_descr%TYPE;
   level_of_serv_on_description       ibridges_staging.level_of_service_on_descr%TYPE;
   main_span_design_description       ibridges_staging.main_span_design_descr%TYPE;
   main_span_material_description     ibridges_staging.main_span_material_descr%TYPE;
   maintenance_region_code            ibridges_staging.maintenance_region%TYPE;
   maintenance_region_description     ibridges_staging.maintenance_region_descr%TYPE;
   maintainer_description             ibridges_staging.maintainer_descr%TYPE;
   minor_span_code_description        ibridges_staging.minor_span_code_descr%TYPE;
   navigation_control_description     ibridges_staging.navigation_control_descr%TYPE;
   neighbor_state_description         ibridges_staging.neighbor_state_code_descr%TYPE;
   on_base_hwy_net_description        ibridges_staging.on_base_highway_network_descr%TYPE;
   op_rating_type_description         ibridges_staging.operating_rating_type_desc%TYPE;
   owner_description                  ibridges_staging.owner_descr%TYPE;
   par_struct_desig_description       ibridges_staging.parallel_structure_desig_descr%TYPE;
   placecode_description              ibridges_staging.placecode_descr%TYPE;
   posted_bridge_ind_description      ibridges_staging.posted_bridge_indicator_descr%TYPE;
   post_type_description              ibridges_staging.post_type_descr%TYPE;
   rail_rating_description            ibridges_staging.rail_rating_descr%TYPE;
   scour_rating_description           ibridges_staging.scour_rating_descr%TYPE;
   Status_description                 ibridges_staging.status_descr%TYPE;
   structure_flared_description       ibridges_staging.structure_flared_descr%TYPE;
   substruct_rating_description       ibridges_staging.substructure_rating_descr%TYPE;
   superstruct_rating_description     ibridges_staging.superstructure_rating_descr%TYPE;
   temp_struct_desig_description      ibridges_staging.temp_structure_desig_descr%TYPE;
   toll_description                   ibridges_staging.toll_descr%TYPE;
   traffic_dir_on_description         ibridges_staging.traffic_direction_on_descr%TYPE;
   transition_rating_description      ibridges_staging.transition_rating_descr%TYPE;
   type_of_service_on_description     ibridges_staging.type_of_service_on_descr%TYPE;
   type_of_serv_under_description     ibridges_staging.type_of_service_under_descr%TYPE;
   userbrdg_maintainr_description     ibridges_staging.userbrdg_maintainer_descr%TYPE;
   userbrdg_owner_description         ibridges_staging.userbrdg_owner_descr%TYPE;
   water_ad_rat_description           ibridges_staging.waterway_adequacy_rating_descr%TYPE;
   
   dapp_guardrail_end_rating   ibridges_staging.app_guardrail_end_rating_descr%TYPE;
   dapp_guardrail_rating       ibridges_staging.app_guardrail_rating_descr%TYPE;
   dapp_road_align_rating      ibridges_staging.app_road_align_rating_descr%TYPE;
   ddeck_geometry_rating       ibridges_staging.deck_geometry_rating_descr%TYPE; 
   dpier_protection_rating     ibridges_staging.pier_protection_rating_descr%TYPE;
   dstructural_evaluation      ibridges_staging.structural_evaluation_descr%TYPE;
   dstructure_open             ibridges_staging.structure_open_descr%TYPE;
   dunderclearance_rating      ibridges_staging.underclearance_rating_descr%TYPE;
   dmin_vert_under_ref_feature ibridges_staging.min_vert_under_ref_feature_descr%type;

   fapproach_span_design              NUMBER;                         -- fe_id
   lapproach_span_design              NUMBER;     -- max length of description
   fapproach_span_material            NUMBER;
   lapproach_span_material            NUMBER;
   fbridge_median                     NUMBER;
   lbridge_median                     NUMBER;
   fbridge_on_off_system              NUMBER;
   lbridge_on_off_system              NUMBER;
   fbridge_posting                    NUMBER;
   lbridge_posting                    NUMBER;
   fchannel_rating                    NUMBER;
   lchannel_rating                    NUMBER;
   fco_maintainer                     NUMBER;
   lco_maintainer                     NUMBER;
   fco_owner                          NUMBER;
   lco_owner                          NUMBER;
   fculvert_rating                    NUMBER;
   lculvert_rating                    NUMBER;
   fdeck_membrane_type                NUMBER;
   ldeck_membrane_type                NUMBER;
   fdeck_protection_code              NUMBER;
   ldeck_protection_code              NUMBER;
   fdeck_structure_type               NUMBER;
   ldeck_structure_type               NUMBER;
   fdeck_rating                       NUMBER;
   ldeck_rating                       NUMBER;
   fdeck_surface_type                 NUMBER;
   ldeck_surface_type                 NUMBER;
   fdesign_load                       NUMBER;
   ldesign_load                       NUMBER;
   ffederal_land_hwy                  NUMBER;
   lfederal_land_hwy                  NUMBER;
   fgeographic_region                 NUMBER;
   lgeographic_region                 NUMBER;
   fhistorical_significance           NUMBER;
   lhistorical_significance           NUMBER;
 
   finventory_rating_type             NUMBER;
   linventory_rating_type             NUMBER;
   finvrte_dirsuffix                  NUMBER;
   finvrte_functionclass              NUMBER;
   finvrte_on_nhs                     NUMBER;
   finvrte_on_strahnet                NUMBER;
   finvrte_on_trucknet                NUMBER;
   linvrte_dirsuffix                  NUMBER;
   linvrte_functionclass              NUMBER;
   linvrte_on_nhs                     NUMBER;
   linvrte_on_strahnet                NUMBER;
   linvrte_on_trucknet                NUMBER;
   flevel_of_service_on               NUMBER;
   llevel_of_service_on               NUMBER;
   fkind_of_highway_on                NUMBER;
   lkind_of_highway_on                NUMBER;
   fmain_span_design                  NUMBER;
   lmain_span_design                  NUMBER;
   fmain_span_material                NUMBER;
   lmain_span_material                NUMBER;
   fmaintainer                        NUMBER;
   lmaintainer                        NUMBER;
   fnavigation_control                NUMBER;
   lnavigation_control                NUMBER;
   fneighbor_state_code               NUMBER;
   lneighbor_state_code               NUMBER;
   foperating_rating_type             NUMBER;
   loperating_rating_type             NUMBER;
   fon_base_highway_network           NUMBER;
   lon_base_highway_network           NUMBER;
   fparallel_structure_desig          NUMBER;
   lparallel_structure_desig          NUMBER;
   fposted_bridge_indicator           NUMBER;
   lposted_bridge_indicator           NUMBER;
   fpost_type                         NUMBER;
   lpost_type                         NUMBER;
   frail_rating                       NUMBER;
   lrail_rating                       NUMBER;
   fscour_rating                      NUMBER;
   lscour_rating                      NUMBER;
   fstatus                            NUMBER;
   lstatus                            NUMBER;
   fstructure_flared                  NUMBER;
   lstructure_flared                  NUMBER;
   fsubstructure_rating               NUMBER;
   lsubstructure_rating               NUMBER;
   fsuperstructure_rating             NUMBER;
   lsuperstructure_rating             NUMBER;
   ftemp_stucture_desig               NUMBER;
   ltemp_stucture_desig               NUMBER;
   ftoll                              NUMBER;
   ltoll                              NUMBER;
   ftraffic_direction_on              NUMBER;
   ltraffic_direction_on              NUMBER;
   ftype_of_service_on                NUMBER;
   ltype_of_service_on                NUMBER;
   ftype_of_service_under             NUMBER;
   ltype_of_service_under             NUMBER;
   fuserbrdg_maintainer               NUMBER;
   luserbrdg_maintainer               NUMBER;
   fuserbrdg_owner                    NUMBER;
   luserbrdg_owner                    NUMBER;
   fwater_adequacy_rating             NUMBER;
   lwater_adequacy_rating             NUMBER;

   fapp_guardrail_end_rating   NUMBER;
   lapp_guardrail_end_rating   NUMBER;
   fapp_guardrail_rating       NUMBER;
   lapp_guardrail_rating       NUMBER;
   fapp_road_align_rating      NUMBER;
   lapp_road_align_rating      NUMBER;
   fdeck_geometry_rating       NUMBER;
   ldeck_geometry_rating       NUMBER;
   fpier_protection_rating     NUMBER;
   lpier_protection_rating     NUMBER;
   fstructural_evaluation      NUMBER;
   lstructural_evaluation      NUMBER;
   fstructure_open             NUMBER;
   lstructure_open             NUMBER;
   funderclearance_rating      NUMBER;
   lunderclearance_rating      NUMBER;
   fmin_vert_under_ref_feature number;
   lmin_vert_under_ref_feature number;


   -- Set up fips_state and fhwa_region which are both '231' in Inspect Tech
   tfips_state_code                   VARCHAR2 (2) := '23';

   tfips_region                       VARCHAR2 (1) := '1';


   fips_state_code_description        ibridges_staging.fips_state_code_desc%TYPE
      := 'Maine';
   fips_region_description            ibridges_staging.fips_region_descr%TYPE
                                         := 'FHWA Region 1-Albany';



   CURSOR brdg
   IS
   SELECT a.bridge_number, bridge_name, abuttoabutdet, app_guardrail_end_rating,app_guardrail_rating, app_road_align_rating,approach_roadway_width,
               approach_span_design, approach_span_material, approach_span_number, asset_status, asset_status_descr,  
               asset_type, border_bridge_percent_resp, border_bridge_number, bridge_group, bridge_indicator, bridge_length, bridge_median,
               bridge_on_off_system, bridge_posting, channel_rating, clear_span_length, config1, config2, co_maintainer, co_owner, culvert_rating,
               curb_sidewalk_width_left, curb_sidewalk_width_right, deck_area, deck_geometry_rating,deck_membrane_type, deck_protection_code, deck_rating,
               deck_structure_type, deck_surface_type, design_load, detour_length, fc_inspection_frequency, fc_inspection_required,
               fc_last_inspection_date, feature_on_structure, feature_under_structure, federal_land_hwy, federal_sufficiency_rating,
               geographic_region, historical_significance, horizontal_clearance, inspection_date, inspection_frequency, inventory_rating,
               inventory_rating_type, invrte_adt, invrte_adt_truck_percent, invrte_adt_yr, invrte_dirsuffix, invrte_functionclass,
               invrte_on_nhs, invrte_lrs_rtenum, invrte_lrs_subrtenum, invrte_rectype, invrte_rtenum, invrte_on_strahnet, invrte_on_trucknet,
               kind_of_highway_on, lanes_under, latitude, length_max_span, level_of_service_on, location_description, longitude, lr_ev2_rating, lr_ev3_rating,maintainer, a.maintenance_region,
               main_span_design, main_span_material, main_span_number, milepoint, min_lat_under_clear_left, min_lat_under_clear_right,
               min_navclr_lift_brdg, min_vertical_clearance_on, min_vertical_under_clearance,min_vert_under_ref_feature, 
               MTRNS_ASSETNO_LEFT_RAMP,MTRNS_ASSETNO_N_OR_E,MTRNS_ASSETNO_OTHER,MTRNS_ASSETNO_PORTAL_N_OR_E,MTRNS_ASSETNO_PORTAL_S_OR_W,MTRNS_ASSETNO_RIGHT_RAMP,MTRNS_ASSETNO_S_OR_W,
               navigation_control, navigation_horizontal,
               navigation_vertical, nbis_bridge_length, nbis_inspection_done, neighbor_state_code, number_lanes, num_axles1,  /* for config1 posting */
               num_axles2,  /* for config2 posting */ l.ol_north_right_ramp_ft,l.ol_north_right_ramp_in,l.OL_PERMIT_LEFT_RAMP_FT,l.OL_PERMIT_LEFT_RAMP_IN,
               l.ol_permit_north_ft, l.ol_permit_north_in,l.OL_PERMIT_OTHER_FT,l.OL_PERMIT_OTHER_IN,l.OL_PERMIT_PORTAL_NORTH_FT,l.OL_PERMIT_PORTAL_NORTH_IN,         
              l.OL_PERMIT_PORTAL_SOUTH_FT, l.OL_PERMIT_PORTAL_SOUTH_IN,l.OL_PERMIT_RIGHT_RAMP_FT,l.OL_PERMIT_RIGHT_RAMP_IN, l.ol_permit_south_ft, l.ol_permit_south_in,
              l.OL_NORTH_MAIN_POSTED, l.OL_NORTH_OTHER_POSTED, l.OL_NORTH_RAMP_POSTED, l.OL_PORTAL_NORTH_POSTED, 
              l.OL_PORTAL_SOUTH_POSTED, l.OL_SOUTH_MAIN_POSTED, l.OL_SOUTH_OTHER_POSTED, l.OL_SOUTH_RAMP_POSTED,  
              L2.LR_POSTED_DATE, L2.OL_NORTH_MAIN_POSTED_FT,L2.OL_NORTH_MAIN_POSTED_IN,   L2.OL_NORTH_OTHER_POSTED_FT,
               L2.OL_NORTH_OTHER_POSTED_IN,L2.OL_NORTH_RAMP_POSTED_FT,L2.OL_NORTH_RAMP_POSTED_IN,L2.OL_PORTAL_NORTH_POSTED_FT,
               L2.OL_PORTAL_NORTH_POSTED_IN,L2.OL_PORTAL_SOUTH_POSTED_FT,L2.OL_PORTAL_SOUTH_POSTED_IN,L2.OL_SOUTH_MAIN_POSTED_FT,
               L2.OL_SOUTH_MAIN_POSTED_IN,L2.OL_SOUTH_OTHER_POSTED_FT,L2.OL_SOUTH_OTHER_POSTED_IN,L2.OL_SOUTH_RAMP_POSTED_FT,L2.OL_SOUTH_RAMP_POSTED_IN,
                on_base_highway_network, operating_rating, operating_rating_type, owner, parallel_structure_desig, pa.parent_asset,
                pier_protection_rating, place_code, posted, posted_weight, posted1truck, posted4axle, postedspacing, posted_bridge_indicator, post_type, rail_rating,
               scour_rating, si_inspection_frequency, si_inspection_required, si_last_inspection_date, skew_angle, status,
               status1, /* for config1, num_axles1 posting */ status2, /* for config2, num_axles2 posting */structural_evaluation,
                structure_flared, structure_open, subcategory,
               substructure_rating, superstructure_rating,  temp_stucture_desig, toll, a.towncode, a.towncode2, traffic_direction_on, transition_rating,
               truck_weight_post_limit, type_of_service_on, type_of_service_under, underclearance_rating, userbrdg_maintainer, userbrdg_owner, uw_inspection_frequency,
               uw_inspection_required, uw_last_inspection_date, vehicle_height_over, vehicle_height_under, vehicle_load_limit, water_adequacy_rating,
               width, width_curb_to_curb, year_built, year_reconstructed, year_last_painted, year_ws_replaced,   c.townname town_name, c.county_code county, c.county county_name,
               d.townname town2_name, d.county_code county2, d.county county2_name
          FROM EXT_BRIDGES a
               INNER JOIN EXT_BRIDGES2 b ON a.bridge_number = b.bridge_number
               INNER JOIN ext_parent pa ON a.bridge_number = pa.bridge_number
               left outer JOIN ext_roads_on_bridge r
                  ON a.bridge_number = r.bridge_number -- roads on bridge contains row for all bridges    
              left outer JOIN ext_lrp p ON a.bridge_number = p.bridge_number  -- Bridge postings from the load-rating form 
               left outer JOIN ext_ol l ON a.bridge_number = l.bridge_number -- Info from the Over Limit from
                LEFT OUTER JOIN ext_ol2 l2 ON a.bridge_number = l2.bridge_number -- Info from the Over Limit Form
               LEFT OUTER JOIN wh_common.dim_towns c ON A.towncode = c.towncode
               LEFT OUTER JOIN wh_common.dim_towns d
                  ON A.towncode2 = d.towncode           
      ORDER BY 1;
  
       

   FUNCTION Calculate_RSL (bridge_no IN VARCHAR,
                           CulvRating     IN VARCHAR,
                           DkRating       IN VARCHAR,
                           DesignMain     IN VARCHAR,
                           MaterialMain   IN VARCHAR,
                           SubRating      IN VARCHAR,
                           SupRating      IN VARCHAR)
      RETURN NUMBER
   IS
      rsl             NUMBER := NULL;
      rsla            NUMBER := 0;
      rslb            NUMBER := 0;
      lowest_rating   NUMBER := 0;
      err       VARCHAR2(100);
   BEGIN
      IF culvrating BETWEEN '0' AND '9'                           -- a culvert
      THEN
         IF materialmain = '3' OR materialMain = '9'      -- steel or aluminum
         THEN
            rsl :=
               CASE
                  WHEN culvrating = '9' THEN 50
                  WHEN culvrating = '8' THEN 45
                  WHEN culvrating = '7' THEN 35
                  WHEN culvrating = '6' THEN 25
                  WHEN culvrating = '5' THEN 15
                  WHEN culvrating = '4' THEN 5
                  WHEN culvrating <= '3' THEN 0
                  ELSE NULL
               END;
         ELSE                                      -- Other non-metal culverts
            rsl :=
               CASE
                  WHEN culvrating = '9' THEN 75
                  WHEN culvrating = '8' THEN 70
                  WHEN culvrating = '7' THEN 60
                  WHEN culvrating = '6' THEN 40
                  WHEN culvrating = '5' THEN 20
                  WHEN culvrating = '4' THEN 10
                  WHEN culvrating <= '3' THEN 0
                  ELSE NULL
               END;
         END IF;                -- IF materialmain = '3' OR materialMain = '9'
      ELSE                                                         -- A Bridge
         IF     (suprating BETWEEN '0' AND '9')
            AND (subrating BETWEEN '0' AND '9')
         THEN
            IF suprating <= subrating -- Use lower of superstructure rating or substructure rating for RSL
            THEN
               lowest_rating := suprating;
            ELSE
               lowest_rating := subrating;
            END IF;                              --  IF suprating <= subrating

            rsla :=
               CASE
                  WHEN lowest_rating = '9' THEN 75
                  WHEN lowest_rating = '8' THEN 70
                  WHEN lowest_rating = '7' THEN 60
                  WHEN lowest_rating = '6' THEN 40
                  WHEN lowest_rating = '5' THEN 20
                  WHEN lowest_rating = '4' THEN 10
                  WHEN lowest_rating <= '3' THEN 0
                  ELSE NULL
               END;
         END IF; -- IF (suprating BETWEEN '0' AND '9')  AND (subrating BETWEEN '0' AND '9')

         IF NOT (designmain = '01' OR designmain = '07')      -- slab or frame
         THEN
            IF (dkrating BETWEEN '0' AND '9')
            THEN
               rslb :=                              -- Use deck rating for RSL
                  CASE
                     WHEN dkrating = '9' THEN 50
                     WHEN dkrating = '8' THEN 45
                     WHEN dkrating = '7' THEN 35
                     WHEN dkrating = '6' THEN 25
                     WHEN dkrating = '5' THEN 15
                     WHEN dkrating = '4' THEN 5
                     WHEN dkrating <= '3' THEN 0
                     ELSE NULL
                  END;

               -- Use lower of superstructure/substructure rating OR deck rating for RSL
               IF rsla <= rslb
               THEN
                  rsl := rsla;
               ELSE
                  rsl := rslb;
               END IF;                                     --  IF rsla <= rslb
            END IF;                      --  IF (dkrating BETWEEN '0' AND '9')
         ELSE
            rsl := rsla;
         END IF; --  IF NOT (designmain = '01' OR designmain = '07') -- slab or frame
      END IF;               -- IF culvrating BETWEEN '0' AND '9'  -- a culvert


      RETURN (rsl);
   EXCEPTION
      WHEN OTHERS
      THEN
         err := 'Error num :'||to_char(sqlcode)||' '||substr(sqlerrm,1,70);
             INSERT INTO data_exceptions (TABLE_NAME,                                
                                      ERROR_CONDITION,                                     
                                      TEST_PROCEDURE,
                                      TEST_DATE,
                                      ASSESSMENT,
                                     COLUMN_NAME1,
                                     COLUMN_VALUE1,
                                     COLUMN_NAME2,
                                     COLUMN_VALUE2)
                      VALUES ('ibridges_staging',
                              err,
                              $$PLSQL_UNIT,
                              common_rundate,
                              'EXCEPTION',
                              'FUNCTION',
                              'Calculate_RSL',
                              'BRIDGE_NUMBER',
                              bridge_no);  
      
         RETURN (NULL);
   END;                                              -- Function calculate_rsl

   PROCEDURE Lookup_fe_id_length (column_name    IN     VARCHAR2,
                                  insp_fe_id        OUT NUMBER,
                                  max_desc_len      OUT NUMBER)
   IS
   -- Procedure to Look up inspecTech field ID and longest length of description
   BEGIN
      SELECT fe_id
        INTO insp_fe_id
        FROM bridge_mappings
       WHERE assets_column = column_name;

      SELECT MAX (LENGTH (description))
        INTO max_desc_len
        FROM bridges_lookup_codes
       WHERE field_id = insp_fe_id;
   END;
BEGIN
      EXECUTE IMMEDIATE 'TRUNCATE TABLE ibridges_staging';
      EXECUTE IMMEDIATE 'TRUNCATE TABLE IBRIDGES_STAGING_ERROR_LOG'; 

   -- Get fe_id and max length of the description for each _descr column
   
   Lookup_fe_id_length ('APP_GUARDRAIL_END_RATING',
                        fapp_guardrail_end_rating,
                        lapp_guardrail_end_rating);
   Lookup_fe_id_length ('APP_GUARDRAIL_RATING',
                        fapp_guardrail_rating,
                        lapp_guardrail_rating);
   Lookup_fe_id_length ('APP_ROAD_ALIGNMENT_RATING',
                        fapp_road_align_rating,
                        lapp_road_align_rating);

   Lookup_fe_id_length ('APPROACH_SPAN_DESIGN',
                        fapproach_span_design,
                        lapproach_span_design);
   Lookup_fe_id_length ('APPROACH_SPAN_MATERIAL',
                        fapproach_span_material,
                        lapproach_span_material);
   Lookup_fe_id_length ('BRIDGE_MEDIAN', fbridge_median, lbridge_median);
   Lookup_fe_id_length ('BRIDGE_ON_OFF_SYSTEM',
                        fbridge_on_off_system,
                        lbridge_on_off_system);
   Lookup_fe_id_length ('BRIDGE_POSTING', fbridge_posting, lbridge_posting);
   Lookup_fe_id_length ('CHANNEL_RATING', fchannel_rating, lchannel_rating);
   Lookup_fe_id_length ('CO_MAINTAINER', fco_maintainer, lco_maintainer);
   Lookup_fe_id_length ('CO_OWNER', fco_owner, lco_owner);
   Lookup_fe_id_length ('CULVERT_RATING', fculvert_rating, lculvert_rating);
    Lookup_fe_id_length ('DECK_GEOMETRY_RATING',
                        fdeck_geometry_rating,
                        ldeck_geometry_rating);
   Lookup_fe_id_length ('DECK_MEMBRANE_TYPE',
                        fdeck_membrane_type,
                        ldeck_membrane_type);
   Lookup_fe_id_length ('DECK_PROTECTION_CODE',
                        fdeck_protection_code,
                        ldeck_protection_code);
   Lookup_fe_id_length ('DECK_RATING', fdeck_rating, ldeck_rating);
   Lookup_fe_id_length ('DECK_STRUCTURE_TYPE',
                        fdeck_structure_type,
                        ldeck_structure_type);
   Lookup_fe_id_length ('DECK_SURFACE_TYPE',
                        fdeck_surface_type,
                        ldeck_surface_type);
   Lookup_fe_id_length ('DESIGN_LOAD', fdesign_load, ldesign_load);
   Lookup_fe_id_length ('FEDERAL_LAND_HWY',
                        ffederal_land_hwy,
                        lfederal_land_hwy);
   Lookup_fe_id_length ('MAINTENANCE_REGION',
                        fgeographic_region,
                        lgeographic_region);
   Lookup_fe_id_length ('HISTORICAL_SIGNIFICANCE',
                        fhistorical_significance,
                        lhistorical_significance);

   Lookup_fe_id_length ('INVENTORY_RATING_TYPE',
                        finventory_rating_type,
                        linventory_rating_type);

   Lookup_fe_id_length ('INVRTE_DIRSUFFIX',
                        finvrte_dirsuffix,
                        linvrte_dirsuffix);

   Lookup_fe_id_length ('INVRTE_FUNCTIONCLASS',
                        finvrte_functionclass,
                        linvrte_functionclass);

   Lookup_fe_id_length ('INVRTE_ON_NHS', finvrte_on_nhs, linvrte_on_nhs);

   Lookup_fe_id_length ('INVRTE_ON_STRAHNET',
                        finvrte_on_strahnet,
                        linvrte_on_strahnet);

   Lookup_fe_id_length ('INVRTE_ON_TRUCKNET',
                        finvrte_on_trucknet,
                        linvrte_on_trucknet);

   Lookup_fe_id_length ('LEVEL_OF_SERVICE_ON',
                        flevel_of_service_on,
                        llevel_of_service_on);
   Lookup_fe_id_length ('KIND_OF_HIGHWAY_ON',
                        fkind_of_highway_on,
                        lkind_of_highway_on);
   Lookup_fe_id_length ('MAIN_SPAN_DESIGN',
                        fmain_span_design,
                        lmain_span_design);
   Lookup_fe_id_length ('MAIN_SPAN_MATERIAL',
                        fmain_span_material,
                        lmain_span_material);
   Lookup_fe_id_length ('MAINTAINER', fmaintainer, lmaintainer);
   Lookup_fe_id_length ('MIN_VERT_UNDER_REF_FEATURE',fmin_vert_under_ref_feature,lmin_vert_under_ref_feature);
   Lookup_fe_id_length ('NAVIGATION_CONTROL',
                        fnavigation_control,
                        lnavigation_control);
   Lookup_fe_id_length ('NEIGHBOR_STATE_CODE',
                        fneighbor_state_code,
                        lneighbor_state_code);
   Lookup_fe_id_length ('OPERATING_RATING_TYPE',
                        foperating_rating_type,
                        loperating_rating_type);
   Lookup_fe_id_length ('ON_BASE_HIGHWAY_NETWORK',
                        fon_base_highway_network,
                        lon_base_highway_network);
   Lookup_fe_id_length ('PARALLEL_STRUCTURE_DESIG',
                        fparallel_structure_desig,
                        lparallel_structure_desig);
   Lookup_fe_id_length ('PIER_PROTECTION_RATING',
                        fpier_protection_rating,
                        lpier_protection_rating);
   Lookup_fe_id_length ('POSTED_BRIDGE_INDICATOR',
                        fposted_bridge_indicator,
                        lposted_bridge_indicator);
   Lookup_fe_id_length ('POST_TYPE', fpost_type, lpost_type);

   Lookup_fe_id_length ('RAIL_RATING', frail_rating, lrail_rating);
   Lookup_fe_id_length ('SCOUR_RATING', fscour_rating, lscour_rating);
   Lookup_fe_id_length ('STATUS', fstatus, lstatus);
    Lookup_fe_id_length ('STRUCTURAL_EVALUATION',
                        fstructural_evaluation,
                        lstructural_evaluation);
  
   Lookup_fe_id_length ('STRUCTURE_FLARED',
                        fstructure_flared,
                        lstructure_flared);
   Lookup_fe_id_length ('STRUCTURE_OPEN', fstructure_open, lstructure_open);
   Lookup_fe_id_length ('SUBSTRUCTURE_RATING',
                        fsubstructure_rating,
                        lsubstructure_rating);
   Lookup_fe_id_length ('SUPERSTRUCTURE_RATING',
                        fsuperstructure_rating,
                        lsuperstructure_rating);
   Lookup_fe_id_length ('TEMP_STUCTURE_DESIG',
                        ftemp_stucture_desig,
                        ltemp_stucture_desig);
   Lookup_fe_id_length ('TOLL', ftoll, ltoll);

   Lookup_fe_id_length ('TRAFFIC_DIRECTION_ON_BRIDGE',
                        ftraffic_direction_on,
                        ltraffic_direction_on);
   Lookup_fe_id_length ('TYPE_OF_SERVICE_ON',
                        ftype_of_service_on,
                        ltype_of_service_on);
   Lookup_fe_id_length ('TYPE_OF_SERVICE_UNDER',
                        ftype_of_service_under,
                        ltype_of_service_under);
   Lookup_fe_id_length ('UNDERCLEARANCE_RATING',
                        funderclearance_rating,
                        lunderclearance_rating);

   Lookup_fe_id_length ('USERBRDG_MAINTAINER',
                        fuserbrdg_maintainer,
                        luserbrdg_maintainer);
   Lookup_fe_id_length ('USERBRDG_OWNER', fuserbrdg_owner, luserbrdg_owner);

   Lookup_fe_id_length ('WATERWAY_ADEQUACY_RATING',
                        fwater_adequacy_rating,
                        lwater_adequacy_rating);


   FOR rec IN brdg
   LOOP
      -- DG 11/5/2025 DOTDW-1090 If inspection date is ASCII 0 set to NULL and create alert
      IF rec.inspection_date = chr(0) THEN
         rec.inspection_date := NULL;
         WH_COMMON.POST_TO_ALERT_LOG (
                'ALERT14',
                'WH_ASSETS',
                $$PLSQL_UNIT,
                   'Bridge Number: '
                || rec.bridge_number
                || ' requires NBI Inspection Date to be entered manually in AssetWise');
      END IF;   
   
      -- Cleanse Operating Rating
      num := Convert_to_number (rec.operating_rating);
      toperating_rating :=
         CASE
            WHEN num = -1 THEN null 
            WHEN (num BETWEEN 99.9 AND 100) THEN 99.9 -- code that indicates no rating analysis has been performed
            ELSE num
         END;
         
      -- Cleanse Inventory Rating
      num := Convert_to_number (rec.inventory_rating);
      tinventory_rating :=
         CASE
            WHEN num = -1 THEN null 
            WHEN (num BETWEEN 99.9 AND 100) THEN 99.9 -- code that indicates no rating analysis has been performed
            ELSE num
         END;

      -- Cleanse min_lat_under_clear_left
      num := Convert_to_number (rec.min_lat_under_clear_left);
      tmin_lat_under_clear_left :=
         CASE WHEN num = 327.76 THEN 99.9     -- InspecTech converted in error
         WHEN num = -1 THEN null
         ELSE num END;


      -- Cleanse min_lat_under_clear_right
      num := Convert_to_number (rec.min_lat_under_clear_right);
      tmin_lat_under_clear_right :=
         CASE WHEN num = 327.76 THEN 99.9    --  InspecTech converted in error
          WHEN num = -1 THEN null                                
          ELSE num END;

      -- Cleanse min_vertical_clearance_on
      num := Convert_to_number (rec.min_vertical_clearance_on);
      tmin_vertical_clearance_on :=
         CASE
            WHEN NUM = 328.05 THEN 99.9 -- INSPECT TECH converted in error
            WHEN num = -1 THEN null                                
            ELSE num 
         END;

      -- Cleanse vehicle_height_over
       num := Convert_to_number (rec.vehicle_height_over);
       tvehicle_height_over :=
         CASE
            WHEN num = 328.05 THEN 99.99 -- INSPECT TECH converted in error
            WHEN num = 327.76 THEN 99.9
            WHEN num = -1 THEN null                                
            ELSE num 
          END;

      -- Convert columns to numeric using function Convert_to_number
      -- Replace -1 returned from function Convert_to_number on data conversion error to null
      -- Some of missing data in Assetwise is stored as null, some as blank.  Blanks will return -1
      -- so these get converted to null
       
      tabut_to_abut_detour := Round(Convert_to_number (rec.abuttoabutdet),1);
      IF tabut_to_abut_detour = -1 THEN tabut_to_abut_detour := NULL; END IF;
     
      tapproach_span_number := Convert_to_number (rec.approach_span_number);
      IF tapproach_span_number = -1 THEN tapproach_span_number := NULL; END IF;
      
      tapproach_roadway_width :=
         Convert_to_number (rec.approach_roadway_width);
      IF tapproach_roadway_width = -1 THEN  tapproach_roadway_width := NULL; END IF;
         
      tasset_status := Convert_to_number (rec.asset_status);
      IF tasset_status = -1 THEN tasset_status := NULL; END IF;
      
      tborder_bridge_percent_resp :=
         Convert_to_number (rec.BORDER_BRIDGE_PERCENT_RESP);
       IF tborder_bridge_percent_resp = -1 THEN  tborder_bridge_percent_resp := NULL; END IF;
         
      tbridge_length := Convert_to_number (rec.bridge_length);
      IF tbridge_length = -1 THEN tbridge_length := NULL; END IF;
      
      tclear_span_length := ROUND(Convert_to_number (rec.clear_span_length),2);
      IF tclear_span_length = -1 THEN tclear_span_length := NULL; END IF;
      
      tcurb_sidewalk_width_left :=
         Convert_to_number (rec.curb_sidewalk_width_left);
      IF tcurb_sidewalk_width_left = -1 THEN tcurb_sidewalk_width_left := NULL; END IF;
         
      tcurb_sidewalk_width_right :=
         Convert_to_number (rec.curb_sidewalk_width_right);
      IF tcurb_sidewalk_width_right = -1 THEN tcurb_sidewalk_width_right := NULL; END IF;
         
      tdeck_area := Convert_to_number (rec.deck_area);
      IF tdeck_area = -1 THEN tdeck_area := NULL; END IF;
      
      tdetour_length := Convert_to_number (rec.detour_length);
      IF tdetour_length = -1 THEN tdetour_length := NULL; END IF;
      
      tfederal_sufficiency_rating :=
         Convert_to_number (rec.federal_sufficiency_rating);
      IF tfederal_sufficiency_rating = -1 THEN tfederal_sufficiency_rating := NULL; END IF;
         
      thorizontal_clearance := Convert_to_number (rec.horizontal_clearance);
      IF thorizontal_clearance = -1 THEN thorizontal_clearance := NULL; END IF;
      
      tinspection_frequency := Convert_to_number (rec.inspection_frequency);
      IF tinspection_frequency = -1 THEN  tinspection_frequency := NULL; END IF;
      
      tinvrte_adt := Convert_to_number (rec.invrte_adt);
      IF tinvrte_adt = -1 THEN tinvrte_adt := NULL; END IF;
      
      tinvrte_adt_truck_percent := Convert_to_number (rec.invrte_adt_truck_percent);
      IF tinvrte_adt_truck_percent = -1 THEN tinvrte_adt_truck_percent := NULL; END IF;  
         
      tinvrte_adt_yr := Convert_to_number (rec.invrte_adt_yr);
      IF tinvrte_adt_yr = -1 THEN tinvrte_adt_yr := NULL; END IF;
      
      tinvrte_dirsuffix := Convert_to_number (rec.invrte_dirsuffix);
      IF tinvrte_dirsuffix = -1 THEN tinvrte_dirsuffix := NULL; END IF;
      
      tinvrte_functionclass := Convert_to_number (rec.invrte_functionclass);
      IF tinvrte_functionclass = -1 THEN tinvrte_functionclass := NULL; END IF;
      
      tinvrte_on_nhs := Convert_to_number (rec.invrte_on_nhs);
      IF tinvrte_on_nhs = -1 THEN tinvrte_on_nhs := NULL; END IF;
      
      tinvrte_rtenum := 
       convert_to_number(substr(rec.invrte_rtenum, 1,length(rec.invrte_rtenum)-1 )); -- strip extra space off end of number
      IF  tinvrte_rtenum = -1 THEN  tinvrte_rtenum := NULL; END IF;
       
      tinvrte_on_strahnet := Convert_to_number (rec.invrte_on_strahnet);
      IF tinvrte_on_strahnet = -1 THEN tinvrte_on_strahnet := NULL; END IF;
      
      tinvrte_on_trucknet := Convert_to_number (rec.invrte_on_trucknet);
      IF tinvrte_on_trucknet = -1 THEN tinvrte_on_trucknet := NULL; END IF;
      
      tlength_max_span := Convert_to_number (rec.length_max_span);
      IF tlength_max_span = -1 THEN tlength_max_span := NULL; END IF;
      
      tlr_ev2_rating := Convert_to_number (rec.lr_ev2_rating);
      IF tlr_ev2_rating = -1 THEN tlr_ev2_rating := NULL; END IF;
      
      tlr_ev3_rating :=  convert_to_number(substr(rec.lr_ev3_rating,1,length(rec.lr_ev3_rating) - 1)); -- strip off extra character at end
      IF tlr_ev3_rating = -1 THEN tlr_ev3_rating := NULL; END IF;
      
      tmain_span_number := Convert_to_number (rec.main_span_number);
      IF tmain_span_number  = -1 THEN tmain_span_number := NULL; END IF;

      tmin_navclr_lift_brdg := Convert_to_number (rec.min_navclr_lift_brdg);
      IF tmin_navclr_lift_brdg = -1 THEN tmin_navclr_lift_brdg := NULL; END IF;
      
      tmin_vertical_under_clearance :=
         Convert_to_number (rec.min_vertical_under_clearance);
      IF tmin_vertical_under_clearance = -1 THEN tmin_vertical_under_clearance := NULL; END IF;
         
      tnavigation_horizontal := Convert_to_number (rec.navigation_horizontal);
      IF tnavigation_horizontal = -1 THEN tnavigation_horizontal := NULL; END IF;
      
      tnavigation_vertical := Convert_to_number (rec.navigation_vertical);
      IF tnavigation_vertical = -1 THEN tnavigation_vertical := NULL; END IF;
      
      tnumber_lanes := Convert_to_number (rec.number_lanes);
      IF tnumber_lanes = -1 THEN tnumber_lanes := NULL; END IF;
      
      tnumber_lanes_under := Convert_to_number (rec.lanes_under);
      IF tnumber_lanes_under = -1 THEN tnumber_lanes_under := NULL; END IF;
      
      tol_north_right_ramp_ft := Convert_to_number (rec.ol_north_right_ramp_ft);
      IF tol_north_right_ramp_ft = -1 THEN tol_north_right_ramp_ft := NULL; END IF;
      
      tol_north_right_ramp_in := Convert_to_number (rec.ol_north_right_ramp_in);
      IF tol_north_right_ramp_in = -1 THEN tol_north_right_ramp_in  := NULL; END IF;
      
      tol_permit_south_ft := Convert_to_number (rec.ol_permit_south_ft);
      IF tol_permit_south_ft = -1 THEN tol_permit_south_ft := NULL; END IF;
      
      tol_permit_south_in := Convert_to_number (rec.ol_permit_south_in);
      IF tol_permit_south_in = -1 THEN tol_permit_south_in := NULL; END IF;
      
      tol_permit_north_ft := Convert_to_number (rec.ol_permit_north_ft);
      IF tol_permit_north_ft = -1 THEN tol_permit_north_ft := NULL; END IF;
      
      tol_permit_north_in := Convert_to_number (rec.ol_permit_north_in);  
      IF tol_permit_north_in  = -1 THEN  tol_permit_north_in  := NULL; END IF;
     
     TOL_PERMIT_LEFT_RAMP_FT := Convert_to_number (rec.OL_PERMIT_LEFT_RAMP_FT);
     IF TOL_PERMIT_LEFT_RAMP_FT = -1 THEN TOL_PERMIT_LEFT_RAMP_FT := NULL; END IF;
     
     TOL_PERMIT_LEFT_RAMP_IN := Convert_to_number (rec.OL_PERMIT_LEFT_RAMP_IN);
     IF TOL_PERMIT_LEFT_RAMP_IN = -1 THEN TOL_PERMIT_LEFT_RAMP_IN := NULL; END IF;
     
     TOL_PERMIT_OTHER_FT := Convert_to_number (rec.OL_PERMIT_OTHER_FT );
     IF TOL_PERMIT_OTHER_FT = -1 THEN TOL_PERMIT_OTHER_FT := NULL; END IF;
     
     TOL_PERMIT_OTHER_IN := Convert_to_number (rec.OL_PERMIT_OTHER_IN);
     IF TOL_PERMIT_OTHER_IN = -1 THEN TOL_PERMIT_OTHER_IN := NULL; END IF;
     
     TOL_PERMIT_PORTAL_NORTH_FT := Convert_to_number (rec.OL_PERMIT_PORTAL_NORTH_FT);
     IF TOL_PERMIT_PORTAL_NORTH_FT = -1 THEN TOL_PERMIT_PORTAL_NORTH_FT := NULL; END IF;
     
     TOL_PERMIT_PORTAL_NORTH_IN := Convert_to_number (rec.OL_PERMIT_PORTAL_NORTH_IN);
     IF TOL_PERMIT_PORTAL_NORTH_IN = -1 THEN TOL_PERMIT_PORTAL_NORTH_IN := NULL; END IF;
     
     TOL_PERMIT_PORTAL_SOUTH_FT := Convert_to_number (rec.OL_PERMIT_PORTAL_SOUTH_FT);
     IF TOL_PERMIT_PORTAL_SOUTH_FT = -1 THEN TOL_PERMIT_PORTAL_SOUTH_FT := NULL; END IF;
     
     TOL_PERMIT_PORTAL_SOUTH_IN := Convert_to_number (rec.OL_PERMIT_PORTAL_SOUTH_IN);
     IF TOL_PERMIT_PORTAL_SOUTH_IN = -1 THEN TOL_PERMIT_PORTAL_SOUTH_IN := NULL; END IF;
     
     TOL_PERMIT_RIGHT_RAMP_FT := Convert_to_number (rec.OL_PERMIT_RIGHT_RAMP_FT);
     IF TOL_PERMIT_RIGHT_RAMP_FT = -1 THEN TOL_PERMIT_RIGHT_RAMP_FT := NULL; END IF;
   
     TOL_PERMIT_RIGHT_RAMP_IN := Convert_to_number (rec.OL_PERMIT_RIGHT_RAMP_IN);
     IF TOL_PERMIT_RIGHT_RAMP_IN = -1 THEN TOL_PERMIT_RIGHT_RAMP_IN := NULL; END IF;
     
     tol_north_main_posted_ft := Convert_to_number (rec.ol_north_main_posted_ft);
     IF tol_north_main_posted_ft = -1 THEN tol_north_main_posted_ft := NULL; END IF;
     
      tol_north_main_posted_in := Convert_to_number (rec.ol_north_main_posted_in);
     IF tol_north_main_posted_in = -1 THEN tol_north_main_posted_in := NULL; END IF;
     
      tol_north_other_posted_ft := Convert_to_number (rec.ol_north_other_posted_ft);
     IF tol_north_other_posted_ft = -1 THEN tol_north_other_posted_ft := NULL; END IF;
     
      tol_north_other_posted_in := Convert_to_number (rec.ol_north_other_posted_in);
     IF tol_north_other_posted_in = -1 THEN tol_north_other_posted_in := NULL; END IF;
     
       tol_north_ramp_posted_ft := Convert_to_number (rec.ol_north_ramp_posted_ft);
     IF tol_north_ramp_posted_ft = -1 THEN tol_north_ramp_posted_ft := NULL; END IF;
     
      tol_north_ramp_posted_in := Convert_to_number (rec.ol_north_ramp_posted_in);
     IF tol_north_ramp_posted_in = -1 THEN tol_north_ramp_posted_in := NULL; END IF;
     
         tol_portal_north_posted_ft := Convert_to_number (rec.ol_portal_north_posted_ft);
     IF tol_portal_north_posted_ft = -1 THEN tol_portal_north_posted_ft := NULL; END IF;
     
      tol_portal_north_posted_in := Convert_to_number (rec.ol_portal_north_posted_in);
     IF tol_portal_north_posted_in = -1 THEN tol_portal_north_posted_in := NULL; END IF;
     
     tol_portal_south_posted_ft := Convert_to_number (rec.ol_portal_south_posted_ft);
     IF tol_portal_south_posted_ft = -1 THEN tol_portal_south_posted_ft := NULL; END IF;
     
     tol_portal_south_posted_in := Convert_to_number (rec.ol_portal_south_posted_in);
     IF tol_portal_south_posted_in = -1 THEN tol_portal_south_posted_in := NULL; END IF;
     
     tol_south_main_posted_ft := Convert_to_number (rec.ol_south_main_posted_ft);
     IF tol_south_main_posted_ft = -1 THEN tol_south_main_posted_ft := NULL; END IF;
     
     tol_south_main_posted_in := Convert_to_number (rec.ol_south_main_posted_in);
     IF tol_south_main_posted_in = -1 THEN tol_south_main_posted_in := NULL; END IF;
     
     tol_south_other_posted_ft := Convert_to_number (rec.ol_south_other_posted_ft);
     IF tol_south_other_posted_ft = -1 THEN tol_south_other_posted_ft := NULL; END IF;
     
     tol_south_other_posted_in := Convert_to_number (rec.ol_south_other_posted_in);
     IF tol_south_other_posted_in = -1 THEN tol_south_other_posted_in := NULL; END IF;
     
      tol_south_ramp_posted_ft := Convert_to_number (rec.ol_south_ramp_posted_ft);
      IF tol_south_ramp_posted_ft = -1 THEN tol_south_ramp_posted_ft := NULL; END IF;
     
      tol_south_ramp_posted_in := Convert_to_number (rec.ol_south_ramp_posted_in);
      IF tol_south_ramp_posted_in = -1 THEN tol_south_ramp_posted_in := NULL; END IF;
     
      tlr_posted_date := TRUNC (convert_to_date (rec.lr_posted_date, 'mm/dd/yyyy'));
      
      tposted_weight_tons   := Convert_to_number (rec.posted_weight);
      IF tposted_weight_tons = -1 THEN tposted_weight_tons := NULL; END IF;
      
      tskew_angle := Convert_to_number (rec.skew_angle);
       IF  tskew_angle = -1 THEN  tskew_angle := NULL; END IF;
       
      ttruck_weight_post_limit := Convert_to_number (rec.truck_weight_post_limit);
      IF  ttruck_weight_post_limit = -1 THEN  ttruck_weight_post_limit := NULL; END IF;
      
      tvehicle_height_under := Convert_to_number (rec.vehicle_height_under);
      IF  tvehicle_height_under = -1 THEN  tvehicle_height_under := NULL; END IF;
      
      tvehicle_load_limit := Convert_to_number (rec.vehicle_load_limit);
      IF  tvehicle_load_limit = -1 THEN  tvehicle_load_limit := NULL; END IF;
      
      twidth_curb_to_curb := Convert_to_number (rec.width_curb_to_curb);
      IF  twidth_curb_to_curb = -1 THEN  twidth_curb_to_curb := NULL; END IF;  
         
      twidth := Convert_to_number (rec.width);
      IF  twidth  = -1 THEN  twidth  := NULL; END IF;
      
      tyear_built := Convert_to_number (rec.year_built);
      IF tyear_built = -1 THEN  tyear_built := NULL; END IF;

      -- Cleanse year_reconstructed

      tyear_reconstructed :=
         Convert_to_number (SUBSTR (rec.year_reconstructed, 1, 4));

      IF tyear_reconstructed = -4 OR tyear_reconstructed = -1 -- convert -4, -1 to 0 indicating never reconstructed
      THEN
         tyear_reconstructed := 0;
      END IF;

      -- Lookup Descriptions
      
       dapp_guardrail_end_rating :=
         bridge_lookup (fapp_guardrail_end_rating,
                       rec.app_guardrail_end_rating,
                        lapp_guardrail_end_rating);

      dapp_guardrail_rating :=
         bridge_lookup (fapp_guardrail_rating,
                        substr(rec.app_guardrail_rating,1,1),
                        lapp_guardrail_rating);
      dapp_road_align_rating :=
         bridge_lookup (fapp_road_align_rating,
                        rec.app_road_align_rating,
                        lapp_road_align_rating);

      appspan_design_description :=
         bridge_lookup (fapproach_span_design,
                        rec.approach_span_design,
                        lapproach_span_design);

      appspan_material_description :=
         bridge_lookup (fapproach_span_material,
                        rec.approach_span_material,
                        lapproach_span_material);

      bridge_median_description :=
         bridge_lookup (fbridge_median, rec.bridge_median, lbridge_median);

      bridge_on_off_sys_description :=
         bridge_lookup (fbridge_on_off_system,
                        rec.bridge_on_off_system,
                        lbridge_on_off_system);

      bridge_posting_description :=
         bridge_lookup (fbridge_posting, rec.bridge_posting, lbridge_posting);

      channel_rating_description :=
         bridge_lookup (fchannel_rating, rec.channel_rating, lchannel_rating);

      co_maintainer_description :=
         bridge_lookup (fco_maintainer, rec.co_maintainer, lco_maintainer);

      co_owner_description :=
         bridge_lookup (fco_owner, rec.co_owner, lco_owner);


      culvert_rating_description :=
         bridge_lookup (fculvert_rating, rec.culvert_rating, lculvert_rating);
         
         ddeck_geometry_rating :=
         bridge_lookup (fdeck_geometry_rating,
                        rec.deck_geometry_rating,
                        ldeck_geometry_rating);

      deck_membrane_type_description :=
         bridge_lookup (fdeck_membrane_type,
                        rec.deck_membrane_type,
                        ldeck_membrane_type);

      deck_protection_description :=
         bridge_lookup (fdeck_protection_code,
                        rec.deck_protection_code,
                        ldeck_protection_code);

      deck_struct_type_description :=
         bridge_lookup (fdeck_structure_type,
                        rec.deck_structure_type,
                        ldeck_structure_type);


      deck_rating_description :=
         bridge_lookup (fdeck_rating, rec.deck_rating, ldeck_rating);

      deck_surface_type_description :=
         bridge_lookup (fdeck_surface_type,
                        rec.deck_surface_type,
                        ldeck_surface_type);


      design_load_description :=
         bridge_lookup (fdesign_load, rec.design_load, ldesign_load);


      federal_land_hwy_description :=
         bridge_lookup (ffederal_land_hwy,
                        rec.federal_land_hwy,
                        lfederal_land_hwy);

      geo_region_description :=
         bridge_lookup (fgeographic_region,
                        rec.geographic_region,
                        lgeographic_region);


      historical_sig_description :=
         bridge_lookup (fhistorical_significance,
                        rec.historical_significance,
                        lhistorical_significance);

      inv_rating_type_description :=
         bridge_lookup (finventory_rating_type,
                        rec.inventory_rating_type,
                        linventory_rating_type);

      invrte_dirsuffix_description :=
         bridge_lookup (finvrte_dirsuffix,
                        rec.invrte_dirsuffix,
                        linvrte_dirsuffix);
      dinvrte_functionclass_descr :=
         bridge_lookup (finvrte_functionclass,
                        rec.invrte_functionclass,
                        linvrte_functionclass);
      invrte_on_nhs_description :=
         bridge_lookup (finvrte_on_nhs, rec.invrte_on_nhs, linvrte_on_nhs);
      invrte_on_strahnet_description :=
         bridge_lookup (finvrte_on_strahnet,
                        rec.invrte_on_strahnet,
                        linvrte_on_strahnet);
      invrte_on_trucknet_description :=
         bridge_lookup (finvrte_on_trucknet,
                        rec.invrte_on_trucknet,
                        linvrte_on_trucknet);

      level_of_serv_on_description :=
         bridge_lookup (flevel_of_service_on,
                        rec.level_of_service_on,
                        llevel_of_service_on);

      kind_of_highway_on_description :=
         bridge_lookup (fkind_of_highway_on,
                        rec.kind_of_highway_on,
                        lkind_of_highway_on);

      main_span_design_description :=
         bridge_lookup (fmain_span_design,
                        rec.main_span_design,
                        lmain_span_design);


      main_span_material_description :=
         bridge_lookup (fmain_span_material,
                        rec.main_span_material,
                        lmain_span_material);

      maintainer_description :=
         bridge_lookup (fmaintainer, rec.maintainer, lmaintainer);

      -- owner description uses the same description as maintainer description
      owner_description := bridge_lookup (fmaintainer, rec.owner, lmaintainer);

      -- Minor Span code description, not in InspecTech or Pontis

      minor_span_code_description :=
         CASE
            WHEN rec.subcategory = 'S971 - MSTW'
            THEN
               'Minor Span on Town Way'
            WHEN rec.subcategory = 'S971 - MSSA'
            THEN
               'Minor Span on State Aid Road'
            WHEN rec.subcategory = 'S971 - MSSH'
            THEN
               'Minor Span on State Highway'
            WHEN rec.subcategory = 'S971 - OTHMS'
            THEN
               'Other Minor Span'
            WHEN rec.subcategory = 'S971 - RRMS'
            THEN
               'Railroad Minor Span'
            WHEN rec.subcategory = 'S971 - LURB'
            THEN
               'Low Use/Redundant Bridge'
            WHEN rec.subcategory = 'S971 - BSH'
            THEN
               'Bridge on State Highway'
            WHEN rec.subcategory = 'S971 - BTWSA'
            THEN
               'Bridge on Townway or State Aid Road'
            WHEN rec.subcategory = 'S971 - OTHB'
            THEN
               'Other Bridge'
            WHEN rec.subcategory = 'S971 - RRB'
            THEN
               'Railroad Bridge'
            WHEN rec.subcategory = 'S971 - MTA'
            THEN
               'Maine Turnpike Authority'
            WHEN rec.subcategory = '-1'
            THEN
               'No Bridge/Minor Span Code Assigned'
            ELSE
               'Unknown'
         END;

     dmin_vert_under_ref_feature :=  bridge_lookup (fmin_vert_under_ref_feature ,
                        substr(rec.min_vert_under_ref_feature,1,1) ,
                        lmin_vert_under_ref_feature );

      navigation_control_description :=
         bridge_lookup (fnavigation_control,
                        rec.navigation_control,
                        lnavigation_control);

      neighbor_state_description :=
         bridge_lookup (fneighbor_state_code,
                        rec.neighbor_state_code,
                        lneighbor_state_code);

      op_rating_type_description :=
         bridge_lookup (foperating_rating_type,
                        rec.operating_rating_type,
                        loperating_rating_type);

      on_base_hwy_net_description :=
         bridge_lookup (fon_base_highway_network,
                        rec.on_base_highway_network,
                        lon_base_highway_network);

      par_struct_desig_description :=
         bridge_lookup (fparallel_structure_desig,
                        rec.parallel_structure_desig,
                        lparallel_structure_desig);
                        
     dpier_protection_rating :=
         bridge_lookup (fpier_protection_rating,
                        rec.pier_protection_rating,
                        lpier_protection_rating);

      posted_bridge_ind_description :=
         bridge_lookup (fposted_bridge_indicator,
                        rec.posted_bridge_indicator,
                        lposted_bridge_indicator);


      post_type_description :=
         bridge_lookup (fpost_type, rec.post_type, lpost_type);


      rail_rating_description :=
         bridge_lookup (frail_rating, rec.rail_rating, lrail_rating);

      -- transition rating description uses the same description as rail rating description
      transition_rating_description :=
         bridge_lookup (frail_rating, rec.transition_rating, lrail_rating);

      scour_rating_description :=
         bridge_lookup (fscour_rating, rec.scour_rating, lscour_rating);

      status_description := bridge_lookup (fstatus, rec.status, lstatus);

      structure_flared_description :=
         bridge_lookup (fstructure_flared,
                        rec.structure_flared,
                        lstructure_flared);
                        
      dstructural_evaluation := bridge_lookup (fstructural_evaluation,rec.structural_evaluation,lstructural_evaluation);
      dstructure_open := bridge_lookup (fstructure_open, rec.structure_open, lstructure_open);

      substruct_rating_description :=
         bridge_lookup (fsubstructure_rating,
                        rec.substructure_rating,
                        lsubstructure_rating);


      superstruct_rating_description :=
         bridge_lookup (fsuperstructure_rating,
                        rec.superstructure_rating,
                        lsuperstructure_rating);

      temp_struct_desig_description :=
         bridge_lookup (ftemp_stucture_desig,
                        rec.temp_stucture_desig,
                        ltemp_stucture_desig);

      toll_description := bridge_lookup (ftoll, rec.toll, ltoll);

      traffic_dir_on_description :=
         bridge_lookup (ftraffic_direction_on,
                        rec.traffic_direction_on,
                        ltraffic_direction_on);

      type_of_service_on_description :=
         bridge_lookup (ftype_of_service_on,
                        rec.type_of_service_on,
                        ltype_of_service_on);

      type_of_serv_under_description :=
         bridge_lookup (ftype_of_service_under,
                        rec.type_of_service_under,
                        ltype_of_service_under);
                        
        dunderclearance_rating :=  bridge_lookup (funderclearance_rating, substr(rec.underclearance_rating,1,1), lunderclearance_rating);

      userbrdg_maintainr_description :=
         bridge_lookup (fuserbrdg_maintainer,
                        rec.userbrdg_maintainer,
                        luserbrdg_maintainer);



      userbrdg_owner_description :=
         bridge_lookup (fuserbrdg_owner,
                        SUBSTR (rec.userbrdg_owner, 1, 1),
                        luserbrdg_owner);


      water_ad_rat_description :=
         bridge_lookup (fwater_adequacy_rating,
                        rec.water_adequacy_rating,
                        lwater_adequacy_rating);



      -- No place code description in InspecTech lookup file, so still using pontis


      placecode_description :=
         bridge_description_lookup ('bridge',
                                    'placecode',
                                    TRIM (rec.place_code),
                                    35);



      -- Transform Maintenance_Region

      maintenance_region_code :=
         CASE
            WHEN rec.maintenance_region LIKE '%1%' THEN 1
            WHEN rec.maintenance_region LIKE '%2%' THEN 2
            WHEN rec.maintenance_region LIKE '%3%' THEN 3
            WHEN rec.maintenance_region LIKE '%4%' THEN 4
            WHEN rec.maintenance_region LIKE '%5%' THEN 5
            WHEN rec.maintenance_region LIKE '%Western%' THEN 3
            ELSE 0
         END;


      IF maintenance_region_code <> 0
      THEN
         SELECT region_desc
           INTO maintenance_region_description
           FROM WH_COMMON.DIM_REGIONS
          WHERE '8' || maintenance_region_code = region;
      ELSE maintenance_region_description := null;
      END IF;

      -- Calculate Remaining Service Life

      trsl :=
         Calculate_RSL (rec.bridge_number,rec.Culvert_Rating,
                        rec.Deck_Rating,
                        rec.Main_span_Design,
                        rec.Main_span_Material,
                        rec.Substructure_Rating,
                        rec.Superstructure_Rating);


         INSERT INTO ibridges_staging (bridge_number, bridge_name,abut_to_abut_detour, app_guardrail_end_rating, app_guardrail_end_rating_descr, app_guardrail_rating,
                      app_guardrail_rating_descr,app_road_align_rating, app_road_align_rating_descr,approach_roadway_width, approach_span_design, 
                      approach_span_design_descr, approach_span_material, approach_span_material_descr, approach_span_number, asset_status, asset_status_descr, asset_type, border_bridge_number,
                     border_bridge_percent_resp,bridge_group,bridge_indicator,bridge_length,bridge_median, bridge_median_descr, bridge_on_off_system,
                     bridge_on_off_system_descr, bridge_posting, bridge_posting_descr, channel_rating, channel_rating_descr, clear_span_length,
                     co_maintainer, co_maintainer_descr, co_owner, co_owner_descr, culvert_rating, culvert_rating_descr, curb_sidewalk_width_left,
                     curb_sidewalk_width_right, deck_area, deck_geometry_rating,deck_geometry_rating_descr, deck_membrane_type, deck_membrane_type_descr, deck_protection_code, deck_protection_descr,
                     deck_rating, deck_rating_descr, deck_structure_type, deck_structure_type_descr, deck_surface_type, deck_surface_type_descr,
                     design_load, design_load_descr,detour_length,fc_inspection_frequency, fc_inspection_required, fc_last_inspection, feature_on_structure,
                     feature_under_structure,federal_land_hwy,federal_land_hwy_descr,federal_sufficiency_rating,fips_region,fips_region_descr,fips_state_code,
                     fips_state_code_desc, geographic_region, geographic_region_descr, historical_significance, historical_significance_descr,
                     horizontal_clearance,inspection_date,inspection_frequency,inventory_rating,inventory_rating_type,
                     inventory_rating_type_descr,invrte_adt,invrte_adt_truck_percent,invrte_adt_yr, invrte_dirsuffix, invrte_dirsuffix_descr,
                     invrte_functionclass, invrte_functionclass_descr, invrte_on_nhs, invrte_on_nhs_descr, invrte_lrs_rtenum, invrte_lrs_subrtenum,
                     invrte_rectype, invrte_rtenum, invrte_on_strahnet, invrte_on_strahnet_descr, invrte_on_trucknet, invrte_on_trucknet_descr,
                     kind_of_highway_on, kind_of_highway_on_descr, latitude, length_max_span, level_of_service_on, level_of_service_on_descr,
                     lr_ev2_rating, lr_ev3_rating, location_description, longitude,
                     maintainer, maintainer_descr, maintenance_region, maintenance_region_descr, main_span_design, main_span_design_descr, main_span_material,
                     main_span_material_descr, main_span_number, minor_span_code_descr,min_lat_under_clear_left, min_lat_under_clear_right,min_navclr_lift_brdg,
                     min_vertical_clearance_on, min_vert_under_clearance, min_vert_under_ref_feature, min_vert_under_ref_feature_descr, 
                     MTRNS_ASSETNO_LEFT_RAMP,MTRNS_ASSETNO_N_OR_E,MTRNS_ASSETNO_OTHER,MTRNS_ASSETNO_PORTAL_N_OR_E,MTRNS_ASSETNO_PORTAL_S_OR_W,MTRNS_ASSETNO_RIGHT_RAMP,MTRNS_ASSETNO_S_OR_W,                     
                     navigation_control, navigation_control_descr, navigation_horizontal,
                     navigation_vertical, nbis_bridge_length, nbis_inspection_done, neighbor_state_code, neighbor_state_code_descr, number_lanes,
                     number_lanes_under, milepoint, -- change from offset to milepoint 2/17/17 
                     ol_north_right_ramp_ft,ol_north_right_ramp_in,OL_PERMIT_LEFT_RAMP_FT,OL_PERMIT_LEFT_RAMP_IN,
                     ol_permit_north_ft, ol_permit_north_in,OL_PERMIT_OTHER_FT,OL_PERMIT_OTHER_IN,OL_PERMIT_PORTAL_NORTH_FT,OL_PERMIT_PORTAL_NORTH_IN,         
                     OL_PERMIT_PORTAL_SOUTH_FT, OL_PERMIT_PORTAL_SOUTH_IN,OL_PERMIT_RIGHT_RAMP_FT,OL_PERMIT_RIGHT_RAMP_IN, ol_permit_south_ft, ol_permit_south_in,
                     OL_NORTH_MAIN_POSTED, OL_NORTH_OTHER_POSTED, OL_NORTH_RAMP_POSTED, OL_PORTAL_NORTH_POSTED, 
                     OL_PORTAL_SOUTH_POSTED, OL_SOUTH_MAIN_POSTED, OL_SOUTH_OTHER_POSTED, OL_SOUTH_RAMP_POSTED,  
                     LR_POSTED_DATE, OL_NORTH_MAIN_POSTED_FT,OL_NORTH_MAIN_POSTED_IN,   OL_NORTH_OTHER_POSTED_FT,
                   OL_NORTH_OTHER_POSTED_IN,OL_NORTH_RAMP_POSTED_FT,OL_NORTH_RAMP_POSTED_IN,OL_PORTAL_NORTH_POSTED_FT,
                   OL_PORTAL_NORTH_POSTED_IN,OL_PORTAL_SOUTH_POSTED_FT,OL_PORTAL_SOUTH_POSTED_IN,OL_SOUTH_MAIN_POSTED_FT,
                   OL_SOUTH_MAIN_POSTED_IN,OL_SOUTH_OTHER_POSTED_FT,OL_SOUTH_OTHER_POSTED_IN,OL_SOUTH_RAMP_POSTED_FT,OL_SOUTH_RAMP_POSTED_IN, 
                     on_base_highway_network,on_base_highway_network_descr,operating_rating,operating_rating_type,operating_rating_type_desc,
                     owner,owner_descr,parallel_structure_desig, parallel_structure_desig_descr, Parent_asset, pier_protection_rating,
                     pier_protection_rating_descr,placecode, placecode_descr, posted_bridge_indicator,
                     posted_bridge_indicator_descr, posted, posted_weight_tons, posted_1_truck, posted_4_axle, posted_spacing, posted_5axle_crane, 
                     posted_5axle_crane_dolly, post_type, post_type_descr, rail_rating, rail_rating_descr, remaining_service_life, scour_rating,
                     scour_rating_descr, si_inspection_frequency, si_inspection_required, si_last_inspection, skew_angle, status, status_descr, 
                     structural_evaluation, structural_evaluation_descr, structure_flared, structure_flared_descr,  structure_open,
                     structure_open_descr,subcategory, substructure_rating, substructure_rating_descr, superstructure_rating,
                     superstructure_rating_descr, temp_stucture_desig, temp_structure_desig_descr, toll, toll_descr, towncode, towncode2,
                     traffic_direction_on_bridge, traffic_direction_on_descr, transition_rating, transition_rating_descr, truck_weight_post_limit,
                     type_of_service_on, type_of_service_on_descr, type_of_service_under, type_of_service_under_descr,    underclearance_rating,
                     underclearance_rating_descr,underwater_inspection_done,
                     userbrdg_maintainer, userbrdg_maintainer_descr, userbrdg_owner, userbrdg_owner_descr, uw_inspection_frequency, uw_inspection_required,
                     uw_last_inspection, vehicle_height_over, vehicle_height_under, vehicle_load_limit, waterway_adequacy_rating,waterway_adequacy_rating_descr,
                     width, width_curb_to_curb, year_built, year_reconstructed, year_last_painted, year_ws_replaced , 
                     town_name1, county, county_name,town_name2, county2, county2_name)
                 VALUES (rec.bridge_number, rec.bridge_name, tabut_to_abut_detour,
                        CASE WHEN ASCII(rec.app_guardrail_end_rating) = 0  -- convert blank to null
                        THEN NULL
                        ELSE rec.app_guardrail_end_rating
                        END, 
                        dapp_guardrail_end_rating,  
                        CASE WHEN ASCII(SUBSTR(rec.app_guardrail_rating,1,1)) = 0  -- convert blank to null
                        THEN NULL
                        ELSE SUBSTR(rec.app_guardrail_rating,1,1)
                         END, 
                        dapp_guardrail_rating,
                        CASE WHEN ASCII(rec.app_road_align_rating) = 0  -- convert blank to null
                        THEN NULL
                        ELSE 
                        rec.app_road_align_rating 
                        END, 
                        dapp_road_align_rating,tapproach_roadway_width, rec.approach_span_design, appspan_design_description,
                        rec.approach_span_material, appspan_material_description, tapproach_span_number,  tasset_status, rec.asset_status_descr,rec.asset_type, rec.border_bridge_number,
                        tborder_bridge_percent_resp, rec.bridge_group, rec.bridge_indicator, tbridge_length, rec.bridge_median, bridge_median_description,
                        rec.bridge_on_off_system, bridge_on_off_sys_description, rec.bridge_posting, bridge_posting_description,
                        CASE WHEN ASCII(rec.channel_rating) = 0  -- convert blank to null
                        THEN NULL
                        ELSE 
                        rec.channel_rating
                        END,
                        channel_rating_description, tclear_span_length, rec.co_maintainer, co_maintainer_description, rec.co_owner, co_owner_description,
                        CASE WHEN ASCII(rec.culvert_rating) = 0  -- convert blank to null
                        THEN NULL
                        ELSE rec.culvert_rating END, 
                        culvert_rating_description, tcurb_sidewalk_width_left, tcurb_sidewalk_width_right, tdeck_area,
                        CASE WHEN ASCII(rec.deck_geometry_rating) = 0  -- convert blank to null
                        THEN NULL
                        ELSE  rec.deck_geometry_rating 
                        END, 
                        ddeck_geometry_rating, rec.deck_membrane_type,deck_membrane_type_description, rec.deck_protection_code, deck_protection_description, 
                        CASE WHEN ASCII(rec.deck_rating) = 0  -- convert blank to null
                        THEN NULL
                        ELSE  rec.deck_rating 
                        END, 
                        deck_rating_description,rec.deck_structure_type, deck_struct_type_description, rec.deck_surface_type, deck_surface_type_description, 
                        rec.design_load, design_load_description, tdetour_length,
                        CASE
                        WHEN Convert_to_number (rec.fc_inspection_frequency) = -1
                        THEN NULL
                        ELSE Convert_to_number (rec.fc_inspection_frequency)
                        END,
                        rec.fc_inspection_required, TRUNC ( convert_to_date (rec.fc_last_inspection_date, 'mm/dd/yyyy')),
                         rec.feature_on_structure,rec.feature_under_structure,rec.federal_land_hwy,federal_land_hwy_description, tfederal_sufficiency_rating,
                         tfips_region, fips_region_description, tfips_state_code, fips_state_code_description, rec.geographic_region, geo_region_description,
                         rec.historical_significance, historical_sig_description, thorizontal_clearance, TO_DATE (rec.inspection_date, 'MM/DD/YYYY'),tinspection_frequency,
                          tinventory_rating, rec.inventory_rating_type, inv_rating_type_description,
                         tinvrte_adt, tinvrte_adt_truck_percent, tinvrte_adt_yr, tinvrte_dirsuffix, invrte_dirsuffix_description, tinvrte_functionclass,
                         dinvrte_functionclass_descr, tinvrte_on_nhs, invrte_on_nhs_description, rec.invrte_lrs_rtenum, rec.invrte_lrs_subrtenum,
                         rec.invrte_rectype, tinvrte_rtenum, tinvrte_on_strahnet, invrte_on_strahnet_description, tinvrte_on_trucknet,
                         invrte_on_trucknet_description, rec.kind_of_highway_on, kind_of_highway_on_description, to_char(round(convert_to_number (rec.latitude), 5)),   
                         tlength_max_span, rec.level_of_service_on, level_of_serv_on_description,
                         tlr_ev2_rating,tlr_ev3_rating, rec.location_description,
                         CASE
                           WHEN SUBSTR(rec.longitude,1,1) = '-'
                           THEN SUBSTR(rec.longitude,1,9)
                           ELSE  '-'|| SUBSTR(rec.longitude,1,8)  -- add minus sign to longitude when it is missing
                         END,
                         rec.maintainer, maintainer_description,
                         maintenance_region_code, maintenance_region_description, rec.main_span_design, main_span_design_description, rec.main_span_material,
                         main_span_material_description, tmain_span_number, minor_span_code_description, tmin_lat_under_clear_left, tmin_lat_under_clear_right,
                         tmin_navclr_lift_brdg, tmin_vertical_clearance_on, tmin_vertical_under_clearance,
                         substr(rec.min_vert_under_ref_feature,1,1), dmin_vert_under_ref_feature, 
                         rec.MTRNS_ASSETNO_LEFT_RAMP,rec.MTRNS_ASSETNO_N_OR_E,rec.MTRNS_ASSETNO_OTHER,rec.MTRNS_ASSETNO_PORTAL_N_OR_E,
                         rec.MTRNS_ASSETNO_PORTAL_S_OR_W,rec.MTRNS_ASSETNO_RIGHT_RAMP,rec.MTRNS_ASSETNO_S_OR_W,
                         rec.navigation_control,navigation_control_description,
                         tnavigation_horizontal, tnavigation_vertical, rec.nbis_bridge_length, rec.nbis_inspection_done, rec.neighbor_state_code,
                         neighbor_state_description, tnumber_lanes, tnumber_lanes_under,
                         Convert_to_number(rec.milepoint),  
                         tol_north_right_ramp_ft,tol_north_right_ramp_in,tOL_PERMIT_LEFT_RAMP_FT,tOL_PERMIT_LEFT_RAMP_IN,
                         tol_permit_north_ft, tol_permit_north_in,tOL_PERMIT_OTHER_FT,tOL_PERMIT_OTHER_IN,tOL_PERMIT_PORTAL_NORTH_FT,tOL_PERMIT_PORTAL_NORTH_IN,         
                         tOL_PERMIT_PORTAL_SOUTH_FT, tOL_PERMIT_PORTAL_SOUTH_IN,tOL_PERMIT_RIGHT_RAMP_FT,tOL_PERMIT_RIGHT_RAMP_IN, tol_permit_south_ft, tol_permit_south_in,
                         CASE WHEN substr(rec.OL_NORTH_MAIN_POSTED,1,1) = 'T' THEN 'True'
                              WHEN substr(rec.OL_NORTH_MAIN_POSTED,1,1) = 'F' THEN 'False'
                              ELSE NULL
                         END,     
                         CASE WHEN substr(rec.OL_NORTH_OTHER_POSTED,1,1) = 'T' THEN 'True'
                              WHEN substr(rec.OL_NORTH_OTHER_POSTED,1,1) = 'F' THEN 'False'
                              ELSE NULL
                         END, 
                         CASE WHEN substr(rec.OL_NORTH_RAMP_POSTED,1,1) = 'T' THEN 'True'
                              WHEN substr(rec.OL_NORTH_RAMP_POSTED,1,1) = 'F' THEN 'False'
                              ELSE NULL
                         END, 
                         CASE WHEN substr(rec.OL_PORTAL_NORTH_POSTED,1,1) = 'T' THEN 'True'
                              WHEN substr(rec.OL_PORTAL_NORTH_POSTED,1,1) = 'F' THEN 'False'
                              ELSE NULL
                         END, 
                         CASE WHEN substr(rec.OL_PORTAL_SOUTH_POSTED,1,1) = 'T' THEN 'True'
                              WHEN substr(rec.OL_PORTAL_SOUTH_POSTED,1,1) = 'F' THEN 'False'
                              ELSE NULL
                         END, 
                         CASE WHEN substr(rec.OL_SOUTH_MAIN_POSTED,1,1) = 'T' THEN 'True'
                              WHEN substr(rec.OL_SOUTH_MAIN_POSTED,1,1) = 'F' THEN 'False'
                              ELSE NULL
                         END, 
                         CASE WHEN substr(rec.OL_SOUTH_OTHER_POSTED,1,1) = 'T' THEN 'True'
                              WHEN substr(rec.OL_SOUTH_OTHER_POSTED,1,1) = 'F' THEN 'False'
                              ELSE NULL
                         END,                
                         CASE WHEN substr(rec.OL_SOUTH_RAMP_POSTED,1,1) = 'T' THEN 'True'
                              WHEN substr(rec.OL_SOUTH_RAMP_POSTED,1,1) = 'F' THEN 'False'
                              ELSE NULL
                         END,
                          tLR_POSTED_DATE, tOL_NORTH_MAIN_POSTED_FT,tOL_NORTH_MAIN_POSTED_IN,   tOL_NORTH_OTHER_POSTED_FT,
                   tOL_NORTH_OTHER_POSTED_IN,tOL_NORTH_RAMP_POSTED_FT,tOL_NORTH_RAMP_POSTED_IN,tOL_PORTAL_NORTH_POSTED_FT,
                   tOL_PORTAL_NORTH_POSTED_IN,tOL_PORTAL_SOUTH_POSTED_FT,tOL_PORTAL_SOUTH_POSTED_IN,tOL_SOUTH_MAIN_POSTED_FT,
                   tOL_SOUTH_MAIN_POSTED_IN,tOL_SOUTH_OTHER_POSTED_FT,tOL_SOUTH_OTHER_POSTED_IN,tOL_SOUTH_RAMP_POSTED_FT,tOL_SOUTH_RAMP_POSTED_IN, 
                         rec.on_base_highway_network, on_base_hwy_net_description, toperating_rating, rec.operating_rating_type, op_rating_type_description,
                         rec.owner,owner_description,rec.parallel_structure_desig, par_struct_desig_description, 
                         substr(rec.parent_asset, 1,length(rec.parent_asset)-1 ) , -- strip extra character off end of parent_asset
                         CASE WHEN ASCII(rec.pier_protection_rating) = 0  -- convert blank to null
                         THEN NULL
                         ELSE  rec.pier_protection_rating
                         END,
                         dpier_protection_rating, rec.place_code, placecode_description,
                         rec.posted_bridge_indicator, posted_bridge_ind_description, rec.posted, tposted_weight_tons, rec.posted1truck, rec.posted4axle,  
                         SUBSTR(rec.postedspacing,1,5), rec.status1 /* posted_5axle_crane */, rec.status2 /* posted_5axle_crane_dolly */,
                         rec.post_type, post_type_description, 
                         CASE WHEN ASCII(rec.rail_rating) = 0  -- convert blank to null
                         THEN NULL
                         ELSE rec.rail_rating  
                         END,
                         rail_rating_description, trsl, 
                         CASE WHEN ASCII(rec.scour_rating) = 0  -- convert blank to null
                         THEN NULL
                         ELSE  rec.scour_rating
                         END,
                         scour_rating_description,
                         CASE WHEN Convert_to_number (rec.si_inspection_frequency) = -1
                         THEN NULL
                         ELSE Convert_to_number (rec.si_inspection_frequency)
                         END,
                         rec.si_inspection_required, TRUNC ( convert_to_date (rec.si_last_inspection_date, 'mm/dd/yyyy')),
                         tskew_angle,rec.status,status_description, rec.structural_evaluation, dstructural_evaluation,
                         rec.structure_flared, structure_flared_description, rec.structure_open, dstructure_open, rec.subcategory,
                         CASE WHEN ASCII(rec.substructure_rating) = 0  -- convert blank to null
                         THEN NULL
                         ELSE  rec.substructure_rating 
                         END, 
                         substruct_rating_description, 
                         CASE WHEN ASCII(rec.superstructure_rating) = 0  -- convert blank to null
                         THEN NULL
                         ELSE  rec.superstructure_rating
                         END, 
                         superstruct_rating_description, rec.temp_stucture_desig, temp_struct_desig_description, rec.toll, toll_description,
                         rec.towncode, rec.towncode2, rec.traffic_direction_on, traffic_dir_on_description,
                         CASE WHEN ASCII(rec.transition_rating) = 0  -- convert blank to null
                         THEN NULL
                         ELSE rec.transition_rating
                         END, 
                         transition_rating_description, ttruck_weight_post_limit, 
                         CASE WHEN rec.type_of_service_on IS NULL
                              THEN ' '
                              ELSE rec.type_of_service_on
                              END, 
                               CASE WHEN type_of_service_on_description IS NULL
                              THEN ' '                            
                              ELSE type_of_service_on_description
                              END,
                         rec.type_of_service_under, type_of_serv_under_description, 
                         CASE WHEN ASCII(SUBSTR(rec.underclearance_rating,1,1)) = 0  -- convert blank to null
                         THEN NULL
                         ELSE  SUBSTR(rec.underclearance_rating,1,1)
                         END, 
                         dunderclearance_rating,
                         CASE  -- UNDERWATER_INSPECTION_DONE                     
                           WHEN convert_TO_DATE (rec.uw_last_inspection_date,
                                            'mm/dd/yyyy hh:mi:ss am') IS NOT NULL THEN 1
                           ELSE 0
                         END ,                  
                         rec.userbrdg_maintainer, userbrdg_maintainr_description, SUBSTR (rec.userbrdg_owner, 1, 1), userbrdg_owner_description,
                          CASE
                           WHEN Convert_to_number (
                                   rec.uw_inspection_frequency) = -1
                           THEN
                              NULL
                           ELSE
                              Convert_to_number (rec.uw_inspection_frequency)
                        END,
                        rec.uw_inspection_required, TRUNC (convert_to_date (rec.uw_last_inspection_date, 'mm/dd/yyyy hh:mi:ss am')),
                        tvehicle_height_over,tvehicle_height_under, tvehicle_load_limit,
                         CASE WHEN ASCII(rec.water_adequacy_rating) = 0  -- convert blank to null
                         THEN NULL
                         ELSE rec.water_adequacy_rating
                         END, 
                         water_ad_rat_description,
                        twidth, twidth_curb_to_curb, tyear_built, tyear_reconstructed, rec.year_last_painted, rec.year_ws_replaced, 
                        rec.town_name, rec.county, rec.county_name, rec.town2_name,
                        rec.county2, rec.county2_name)
                 LOG ERRORS INTO ibridges_staging_error_LOG
                        ('Load Ibridges Staging ' || SYSDATE)
                        REJECT LIMIT 100;
     
     commit;
   END LOOP;

   COMMIT;

   -- Check error logs for quality errors
    -- Check ibridges history error log for quality errors

    SELECT COUNT (*)
      INTO errlog_count
      FROM wh_assets.ibridges_staging_error_log;

    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in ibridges_staging_error_log';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'LOAD_IBRIDGE_STAGING',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('IBRIDGES_STAGING_ERROR_LOG',
                         'Invalid data - check error log',
                         procname,
                         common_rundate,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

   SELECT COUNT (*) INTO cntr FROM ibridges_staging;


   WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
      OWNER         => 'WH_ASSETS',
      OBJECT_NAME   => 'IBRIDGES_STAGING',
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
         'Error during ' || $$PLSQL_UNIT || ': ' || SUBSTR (SQLERRM, 1, 400));
      RAISE_APPLICATION_ERROR (-20052, SUBSTR (SQLERRM, 1, 400));
END;
/
