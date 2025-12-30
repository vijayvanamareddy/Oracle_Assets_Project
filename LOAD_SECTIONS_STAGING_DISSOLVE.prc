CREATE OR REPLACE PROCEDURE load_sections_staging_dissolve
IS
    /**********************************************************************
    This procedure loads the sections_staging table from the gis system.

    12-14-18 SH  Initial Version
    01-09-19 SH  HUNDRED_MILLION_VEHICLE_MILES, FUTURE_ADT, FUTURE_ADT_YEAR, TRUCK_PERCENT computed on GIS system
                 instead of in the warehouse
    01-14-19 SH  Remove cross sectional attributes right_lane_crosssection, right_shoulder_type, right_shoulder_type_descr, right_shoulder_width ,
                 left_lane_crosssection, left_shoulder_type, left_shoulder_type_descr, left_shoulder_width as they will be positioned correctly on the route
    01-16-19 SH  Remove route information
    02-11-19 SH  Clean up and modify new_sections_staging to sections_staging table , rename procedure to load_sections_staging
    02-21-19 SH  Add additional columns requested by Ed Beckwidth HPMS_SECTION_ID, NHS_TYPE , NHS_TYPE_DESCR , STRATEGIC_HIGHWAY_NETWORK ,
                 STRATEGIC_HIGHWAY_NETWORK_DESC , LANE_SURFACE_TYPE , LANE_SURFACE_TYPE_DESCR
    03-04-19 SH  Convert access_control to number
    03-26-19 SH  Move from dev to test
    04-05-19 SH  Add columns STATE_AID_NO, STATE_HIGHWAY_DESIGNATION_NUMBER
    09-03-20 SH  Test using match_recognize to reduce segmentation
    09-10-20 SH  Add in cross-sectional columns to segmentation
    09-22-20 SH  Add in segmentation for linear projects  (GIS column linear_project_segment)
    10-16-20 SH Add function to calculate HMVM (HUNDRED_MILLION_VEHICLE_MILES)
    12-01-20 SH Replace match_recognize with F_DISSOLVE function which is the version where the table/view  is passed in as a parameter.  
    **********************************************************************/

    commit_count   NUMBER := 0;
    cntr           NUMBER := 0;

    g_start_time   DATE := SYSDATE;
    g_owner        VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname      VARCHAR2 (30) := 'LOAD_SECTIONS_STAGING_DISSOLVE';
    g_object       VARCHAR2 (20) := 'SECTIONS_STAGING2';
    g_sqlmsg       VARCHAR2 (500) := NULL;


    ele_wid        NUMBER;
    section_len    NUMBER;
    hmvm           NUMBER;

    var_RetVal                SYS_REFCURSOR;
        
    l_route_id   NVARCHAR2 (100);
    l_bmp        NVARCHAR2 (50);
    l_emp        NVARCHAR2 (50);
    l_table      NVARCHAR2 (100);
    l_columns    NVARCHAR2 (32767);
    l_where      NVARCHAR2 (32767);

    l_route_number            NVARCHAR2 (100);
    l_begin_section_mp        NUMBER;
    l_end_section_mp          NUMBER;

-- Variables for columns we are segmenting by      
    l_element_id      NVARCHAR2 (100);
    l_begin_offset NVARCHAR2 (100);
    l_end_offset NVARCHAR2 (100);
    l_aadt NVARCHAR2 (100);
    l_aadt_type NVARCHAR2 (100);
    l_aadt_type_descr NVARCHAR2 (100);
    l_aadt_year NVARCHAR2 (100);
    l_abn NVARCHAR2 (100);
    l_abn_descr NVARCHAR2 (100);
    l_access_control NVARCHAR2 (100);
    l_access_control_descr NVARCHAR2 (100);
    l_agency NVARCHAR2 (100);
    l_agency_descr NVARCHAR2 (100);
    l_bridge_posting_csl NVARCHAR2 (100);
    l_bridge_reliability_csl NVARCHAR2 (100);
    l_capacity NVARCHAR2 (100);
    l_center_turn_lane_count NVARCHAR2 (100);
    l_center_turn_lane_width NVARCHAR2 (100);
    l_condition_csl NVARCHAR2 (100);
    l_congestion_csl NVARCHAR2 (100);
    l_congestion_rate_csl NVARCHAR2 (100);
    l_crash_history_csl NVARCHAR2 (100);
    l_crash_history_rate_csl NVARCHAR2 (100);
    l_csl_year NVARCHAR2 (100);
    l_factored_aadt NVARCHAR2 (100);
    l_factor_year NVARCHAR2 (100);
    l_federal_functional_class NVARCHAR2 (100); 
    l_federal_functional_class_descr NVARCHAR2 (100);        
    l_federal_urban_group NVARCHAR2 (100);
    l_federal_urban_group_descr NVARCHAR2 (100);
    l_federal_urban_rural NVARCHAR2 (100);
    l_federal_urban_rural_descr NVARCHAR2 (100);
    l_future_adt NVARCHAR2 (100);
    l_future_adt_year NVARCHAR2 (100);
    l_hass_description NVARCHAR2 (100);
    l_hass_id NVARCHAR2 (100);
    l_hpms_section_id NVARCHAR2 (100);
    l_iri NVARCHAR2 (100);
    l_jurisdiction NVARCHAR2 (100);
    l_jurisdiction_abbreviation NVARCHAR2 (100);
    l_jurisdiction_code NVARCHAR2 (100);
    l_lane_count NVARCHAR2 (100);
    l_lane_surface_type NVARCHAR2 (100);
    l_lane_surface_type_descr NVARCHAR2 (100);
    l_left_rut NVARCHAR2 (100);
    l_left_turn_lane_count NVARCHAR2 (100);
    l_left_turn_lane_width NVARCHAR2 (100);
    l_left_lane_crosssection NVARCHAR2 (100);
    l_left_shoulder_type NVARCHAR2 (100);
    l_left_shoulder_type_descr NVARCHAR2 (100);
    l_left_shoulder_width NVARCHAR2 (100);
    l_left_sidewalk_type NVARCHAR2 (100);
    l_left_sidewalk_type_descr NVARCHAR2 (100);
    l_left_sidewalk_width NVARCHAR2 (100);
    l_linear_project_segment NVARCHAR2 (100);
    l_maint_resp_winter NVARCHAR2 (100);
    l_maint_resp_winter_descr NVARCHAR2 (100);
    l_maint_resp_yearround NVARCHAR2 (100);
    l_maint_resp_year_descr NVARCHAR2 (100);
    l_mean_sum_deflection_csl NVARCHAR2 (100);
    l_median_average_width NVARCHAR2 (100);
    l_median_type NVARCHAR2 (100);
    l_median_type_descr NVARCHAR2 (100);
    l_min_pavement_width_csl NVARCHAR2 (100);
    l_min_struct_bridge_cond_csl NVARCHAR2 (100);
    l_mpo NVARCHAR2 (100);                                                
    l_national_truck_network NVARCHAR2 (100);
    l_national_truck_network_descr NVARCHAR2 (100);
    l_nhs_status NVARCHAR2 (100);
    l_nhs_type NVARCHAR2 (100);
    l_nhs_type_descr NVARCHAR2 (100);
    l_owner NVARCHAR2 (100);
    l_owner_descr NVARCHAR2 (100);
    l_pavement_condition_csl NVARCHAR2 (100);
    l_pavement_rutting_csl NVARCHAR2 (100);
    l_pavement_width_csl NVARCHAR2 (100);
    l_pcr NVARCHAR2 (100);
    l_plow_crew NVARCHAR2 (100);
    l_pms_file_name NVARCHAR2 (100);
    l_pms_inventory_year NVARCHAR2 (100);
    l_priority NVARCHAR2 (100);
    l_ride_quality_csl NVARCHAR2 (100);
    l_right_rut NVARCHAR2 (100);
    l_right_turn_lane_count NVARCHAR2 (100);
    l_right_turn_lane_width NVARCHAR2 (100);
    l_right_lane_crosssection NVARCHAR2 (100);
    l_right_shoulder_type NVARCHAR2 (100);
    l_right_shoulder_type_descr NVARCHAR2 (100);
    l_right_shoulder_width NVARCHAR2 (100);
    l_right_sidewalk_type NVARCHAR2 (100);
    l_right_sidewalk_type_descr NVARCHAR2 (100);
    l_right_sidewalk_width NVARCHAR2 (100);
    l_roadway_strength_csl NVARCHAR2 (100);
    l_roadway_type NVARCHAR2 (100);
    l_roadway_type_descr NVARCHAR2 (100);
    l_road_posting_csl NVARCHAR2 (100);
    l_rut_csl NVARCHAR2 (100);
    l_safety_csl NVARCHAR2 (100);
    l_scenic_byway_description NVARCHAR2 (500);
    l_scenic_byway_desig_yr NVARCHAR2 (100);
    l_scenic_byway_name NVARCHAR2 (100);
    l_scenic_byway_type NVARCHAR2 (100);
    l_scenic_byway_type_descr NVARCHAR2 (100);
    l_service_csl NVARCHAR2 (100);
    l_sh_sa_ir_designation NVARCHAR2 (100);
    l_speed NVARCHAR2 (100);
    l_speedsrc NVARCHAR2 (100);
    l_speedzn_id NVARCHAR2 (100);
    l_spur_number NVARCHAR2 (100);
    l_state_aid_no NVARCHAR2 (100);
    l_state_designation_number NVARCHAR2 (100);
    l_state_desig_type NVARCHAR2 (100);
    l_state_desig_type_descr NVARCHAR2 (100);
    l_state_hwy_designation_number NVARCHAR2 (100);
    l_state_urban_rural NVARCHAR2 (100);
    l_state_urban_rural_descr NVARCHAR2 (100);
    l_strategic_highway_network NVARCHAR2 (100);
    l_strategic_highway_network_desc NVARCHAR2 (100);
    l_street_name NVARCHAR2 (100);
    l_street_name_prefix NVARCHAR2 (100);
    l_street_name_suffix NVARCHAR2 (100);
    l_struct_bridge_cond_csl NVARCHAR2 (100);
    l_summer_crew NVARCHAR2 (100);
    l_thru_lane_count NVARCHAR2 (100);
    l_thru_lane_width NVARCHAR2 (100);
    l_total_pavement_width NVARCHAR2 (100);
    l_truck_lane_count NVARCHAR2 (100);
    l_truck_lane_width NVARCHAR2 (100);
    l_truck_percent NVARCHAR2 (100);
    l_wcsh_code NVARCHAR2 (100);
    l_wcsh_agreement NVARCHAR2 (100);
    l_weighted_iri_csl NVARCHAR2 (100);
    l_weighted_pcr_csl NVARCHAR2 (100);
    l_width NVARCHAR2 (100);
    l_winter_crew NVARCHAR2 (100);


    FUNCTION Get_element_wid (el_id IN NUMBER)
        RETURN NUMBER
    IS
        ele_wid   NUMBER;                               -- Get the element_wid
        err       VARCHAR2 (100);
    BEGIN
        SELECT element_wid
          INTO ele_wid
          FROM element_history h
         WHERE h.element_id = el_id AND h.state = 'CURRENT';

        RETURN ele_wid;
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
                                         COLUMN_VALUE2)
                 VALUES ('sections_staging2',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'FUNCTION',
                         'Get_element_wid',
                         'ELEMENT_NUMBER',
                         el_id);

            RETURN NULL;
    END;
    
       FUNCTION Calculate_HMVM (aadt_factored   IN NUMBER,
                               section_lngth   IN NUMBER,
                               ele_id IN NUMBER) -- hundred million vehicle miles
         RETURN NUMBER
      IS
         t_hmvm   NUMBER;
         err      VARCHAR2(100);
      BEGIN
         t_hmvm := ( (aadt_factored * (section_lngth)) * 365) / 100000000;

         IF t_hmvm < 0 OR t_hmvm IS NULL
         THEN
            t_hmvm := 0;
         END IF;

         RETURN t_hmvm;
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
                      VALUES ('sections_staging2',
                              err,
                              $$PLSQL_UNIT,
                              g_start_time,
                              'EXCEPTION',
                              'FUNCTION',
                              'Calculate_HMVM',
                              'ELEMENT_ID',
                              ele_id);         
            RETURN NULL;
      END;

BEGIN
    EXECUTE IMMEDIATE 'truncate table sections_staging2';

    EXECUTE IMMEDIATE 'truncate table sections_staging_error_log';
    
    l_route_id := 'route_number';
    l_bmp := 'begin_section_mp';
    l_emp := 'end_section_mp';
    l_table := 'V_WH_BASE_SECTIONS_NO_XSP@GIS';

    l_WHERE := '1=1';
    
    -- Columns we are segmenting by.  These must match the columns in the FETCH statement
     l_COLUMNS :=
                                  'AADT,
                                   AADT_TYPE,
                                   AADT_TYPE_DESCR,
                                   AADT_YEAR,
                                   ABN,
                                   ABN_DESCR,
                                   ACCESS_CONTROL,
                                   ACCESS_CONTROL_DESCR,
                                   AGENCY,
                                   AGENCY_DESCR,
                                   BEGIN_OFFSET,
                                   BRIDGE_POSTING_CSL,
                                   BRIDGE_RELIABILITY_CSL,
                                   CAPACITY,
                                   CENTER_TURN_LANE_COUNT,
                                   CENTER_TURN_LANE_WIDTH,
                                   CONDITION_CSL,
                                   CONGESTION_CSL,
                                   CONGESTION_RATE_CSL,
                                   CRASH_HISTORY_CSL,
                                   CRASH_HISTORY_RATE_CSL,
                                   CSL_YEAR,
                                   ELEMENT_ID, 
                                   END_OFFSET,
                                   FACTORED_AADT,
                                   FACTOR_YEAR,  
                                   FEDERAL_FUNCTIONAL_CLASS,
                                   FEDERAL_FUNCTIONAL_CLASS_DESCR ,    
                                   FEDERAL_URBAN_GROUP,
                                   FEDERAL_URBAN_GROUP_DESCR,
                                   FEDERAL_URBAN_RURAL,
                                   FEDERAL_URBAN_RURAL_DESCR,
                                   FUTURE_ADT,
                                   FUTURE_ADT_YEAR,
                                   HASS_DESCRIPTION,
                                   HASS_ID,
                                   HPMS_SECTION_ID,
                                   IRI,
                                   JURISDICTION,
                                   JURISDICTION_ABBREVIATION,
                                   JURISDICTION_CODE,
                                   LANE_COUNT,
                                   LANE_SURFACE_TYPE,
                                   LANE_SURFACE_TYPE_DESCR,
                                   LEFT_RUT,
                                   LEFT_TURN_LANE_COUNT,
                                   LEFT_TURN_LANE_WIDTH,
                                   LEFT_LANE_CROSSSECTION,
                                   LEFT_SHOULDER_TYPE,
                                   LEFT_SHOULDER_TYPE_DESCR,
                                   LEFT_SHOULDER_WIDTH,
                                   LEFT_SIDEWALK_TYPE,
                                   LEFT_SIDEWALK_TYPE_DESCR,
                                   LEFT_SIDEWALK_WIDTH,
                                   LINEAR_PROJECT_SEGMENT,
                                   MAINT_RESP_WINTER,
                                   MAINT_RESP_WINTER_DESCR,
                                   MAINT_RESP_YEARROUND,
                                   MAINT_RESP_YEAR_DESCR,
                                   MEAN_SUM_DEFLECTION_CSL,
                                   MEDIAN_AVERAGE_WIDTH,
                                   MEDIAN_TYPE,
                                   MEDIAN_TYPE_DESCR,
                                   MIN_PAVEMENT_WIDTH_CSL,
                                   MIN_STRUCT_BRIDGE_COND_CSL,
                                   MPO,
                                   NATIONAL_TRUCK_NETWORK,
                                   NATIONAL_TRUCK_NETWORK_DESCR,
                                   NHS_STATUS,
                                   NHS_TYPE,
                                   NHS_TYPE_DESCR,
                                   OWNER,
                                   OWNER_DESCR,
                                   PAVEMENT_CONDITION_CSL,
                                   PAVEMENT_RUTTING_CSL,
                                   PAVEMENT_WIDTH_CSL,
                                   PCR,
                                   PLOW_CREW,
                                   PMS_FILE_NAME,
                                   PMS_INVENTORY_YEAR,
                                   PRIORITY,
                                   RIDE_QUALITY_CSL,
                                   RIGHT_RUT,
                                   RIGHT_TURN_LANE_COUNT,
                                   RIGHT_TURN_LANE_WIDTH,
                                   RIGHT_LANE_CROSSSECTION,
                                   RIGHT_SHOULDER_TYPE,
                                   RIGHT_SHOULDER_TYPE_DESCR,
                                   RIGHT_SHOULDER_WIDTH,
                                   RIGHT_SIDEWALK_TYPE,
                                   RIGHT_SIDEWALK_TYPE_DESCR,
                                   RIGHT_SIDEWALK_WIDTH,
                                   ROADWAY_STRENGTH_CSL,
                                   ROADWAY_TYPE,
                                   ROADWAY_TYPE_DESCR,
                                   ROAD_POSTING_CSL,
                                   RUT_CSL,
                                   SAFETY_CSL,
                                   SCENIC_BYWAY_DESCRIPTION,
                                   SCENIC_BYWAY_DESIG_YR,
                                   SCENIC_BYWAY_NAME,
                                   SCENIC_BYWAY_TYPE,
                                   SCENIC_BYWAY_TYPE_DESCR,
                                   SERVICE_CSL,
                                   SH_SA_IR_DESIGNATION,
                                   SPEED,
                                   SPEEDSRC,
                                   SPEEDZN_ID,
                                   SPUR_NUMBER,
                                   STATE_AID_NO,
                                   STATE_DESIGNATION_NUMBER,
                                   STATE_DESIG_TYPE,
                                   STATE_DESIG_TYPE_DESCR,
                                   STATE_HWY_DESIGNATION_NUMBER,
                                   STATE_URBAN_RURAL,
                                   STATE_URBAN_RURAL_DESCR,
                                   STRATEGIC_HIGHWAY_NETWORK,
                                   STRATEGIC_HIGHWAY_NETWORK_DESC,
                                   STREET_NAME,
                                   STREET_NAME_PREFIX,
                                   STREET_NAME_SUFFIX,
                                   STRUCT_BRIDGE_COND_CSL,
                                   SUMMER_CREW,                            
                                   THRU_LANE_COUNT,
                                   THRU_LANE_WIDTH,
                                   TOTAL_PAVEMENT_WIDTH,
                                   TRUCK_LANE_COUNT,
                                   TRUCK_LANE_WIDTH,
                                   TRUCK_PERCENT,
                                   WCSH_CODE,
                                   WCSH_AGREEMENT,
                                   WEIGHTED_IRI_CSL,
                                   WEIGHTED_PCR_CSL,
                                   WIDTH,
                                   WINTER_CREW';
                                   

  -- Call the dissolve function
       

       var_RetVal := WH_ASSETS.F_DISSOLVE (l_route_id, l_bmp, l_emp, l_table, l_columns, l_where );

   LOOP
 
            FETCH var_RetVal
                INTO 
                   l_route_number,
                   l_begin_section_mp,
                   l_end_section_mp,
                   l_aadt ,
                   l_aadt_type ,
                   l_aadt_type_descr ,
                   l_aadt_year,
                   l_abn ,
                   l_abn_descr ,
                   l_access_control ,
                   l_access_control_descr ,
                   l_agency ,
                   l_agency_descr ,
                   l_begin_offset,
                   l_bridge_posting_csl ,
                   l_bridge_reliability_csl ,
                   l_capacity ,
                   l_center_turn_lane_count ,
                   l_center_turn_lane_width ,
                   l_condition_csl ,
                   l_congestion_csl ,
                   l_congestion_rate_csl ,
                   l_crash_history_csl ,
                   l_crash_history_rate_csl ,
                   l_csl_year ,
                   l_element_id,
                   l_end_offset,  
                   l_factored_aadt ,
                   l_factor_year ,
                   l_federal_functional_class ,
                   l_federal_functional_class_descr,
                   l_federal_urban_group,
                   l_federal_urban_group_descr,
                   l_federal_urban_rural,
                   l_federal_urban_rural_descr,
                   l_future_adt,
                   l_future_adt_year,
                   l_hass_description,
                   l_hass_id,
                   l_hpms_section_id,
                   l_iri,
                   l_jurisdiction,
                   l_jurisdiction_abbreviation,
                   l_jurisdiction_code,
                   l_lane_count,
                   l_lane_surface_type,
                   l_lane_surface_type_descr,
                   l_left_rut,
                   l_left_turn_lane_count,
                   l_left_turn_lane_width,
                   l_left_lane_crosssection,
                   l_left_shoulder_type,
                   l_left_shoulder_type_descr,
                   l_left_shoulder_width,
                   l_left_sidewalk_type,
                   l_left_sidewalk_type_descr,
                   l_left_sidewalk_width,
                   l_linear_project_segment,
                   l_maint_resp_winter,
                   l_maint_resp_winter_descr,
                   l_maint_resp_yearround,
                   l_maint_resp_year_descr,
                   l_mean_sum_deflection_csl,
                   l_median_average_width,
                   l_median_type,
                   l_median_type_descr,
                   l_min_pavement_width_csl,
                   l_min_struct_bridge_cond_csl,
                   l_mpo,
                   l_national_truck_network,
                   l_national_truck_network_descr,
                   l_nhs_status,
                   l_nhs_type,
                   l_nhs_type_descr,
                   l_owner,
                   l_owner_descr,
                   l_pavement_condition_csl,
                   l_pavement_rutting_csl,
                   l_pavement_width_csl,
                   l_pcr,
                   l_plow_crew,
                   l_pms_file_name,
                   l_pms_inventory_year,
                   l_priority,
                   l_ride_quality_csl,
                   l_right_rut,
                   l_right_turn_lane_count,
                   l_right_turn_lane_width,
                   l_right_lane_crosssection,
                   l_right_shoulder_type,
                   l_right_shoulder_type_descr,
                   l_right_shoulder_width,
                   l_right_sidewalk_type,
                   l_right_sidewalk_type_descr,
                   l_right_sidewalk_width,
                   l_roadway_strength_csl,
                   l_roadway_type,
                   l_roadway_type_descr,
                   l_road_posting_csl,
                   l_rut_csl,
                   l_safety_csl,
                   l_scenic_byway_description,
                   l_scenic_byway_desig_yr,
                   l_scenic_byway_name,
                   l_scenic_byway_type,
                   l_scenic_byway_type_descr,
                   l_service_csl,
                   l_sh_sa_ir_designation,
                   l_speed,
                   l_speedsrc,
                   l_speedzn_id,
                   l_spur_number,
                   l_state_aid_no,
                   l_state_designation_number,
                   l_state_desig_type,
                   l_state_desig_type_descr,
                   l_state_hwy_designation_number,
                   l_state_urban_rural,
                   l_state_urban_rural_descr,
                   l_strategic_highway_network,
                   l_strategic_highway_network_desc,
                   l_street_name,
                   l_street_name_prefix,
                   l_street_name_suffix,
                   l_struct_bridge_cond_csl,
                   l_summer_crew,              
                   l_thru_lane_count,
                   l_thru_lane_width,
                   l_total_pavement_width,
                   l_truck_lane_count,
                   l_truck_lane_width,
                   l_truck_percent,
                   l_wcsh_code,
                   l_wcsh_agreement,
                   l_weighted_iri_csl,
                   l_weighted_pcr_csl,
                   l_width,
                   l_winter_crew;
 
        EXIT WHEN var_RetVal%NOTFOUND;

        ele_wid := Get_element_wid (l_element_id);
        section_len := l_end_offset -  l_begin_offset;
        hmvm:= Calculate_HMVM ( L_FACTORED_AADT  ,
                               section_len,
                               l_element_id);

        INSERT INTO sections_staging2 (aadt,
                                       aadt_type,
                                       aadt_type_descr,
                                       aadt_year,
                                       abn,
                                       abn_descr,
                                       access_control,
                                       access_control_descr,
                                       agency,
                                       agency_descr,
                                       begin_offset,
                                       bridge_posting_csl,
                                       bridge_reliability_csl,
                                       capacity,
                                       center_turn_lane_count,
                                       center_turn_lane_width,
                                       condition_csl,
                                       congestion_csl,
                                       congestion_rate_csl,
                                       crash_history_csl,
                                       crash_history_rate_csl,
                                       csl_year,
                                       element_id,
                                       element_wid,
                                       end_offset,
                                       factored_aadt,
                                       factor_year,
                                       federal_functional_class,
                                       federal_functional_class_descr,
                                       federal_urban_group,
                                       federal_urban_group_descr,
                                       federal_urban_rural,
                                       federal_urban_rural_descr,
                                       future_adt,
                                       future_adt_year,
                                       hass_description,
                                       hass_id,
                                       hpms_section_id,
                                       hundred_million_vehicle_miles,
                                       iri,
                                       jurisdiction,
                                       jurisdiction_abbreviation,
                                       jurisdiction_code,
                                       lane_count,
                                       lane_surface_type,
                                       lane_surface_type_descr,
                                       left_rut,
                                       left_turn_lane_count,
                                       left_turn_lane_width,
                                       maint_resp_winter,
                                       maint_resp_winter_descr,
                                       maint_resp_yearround,
                                       maint_resp_year_descr,
                                       mean_sum_deflection_csl,
                                       median_average_width,
                                       median_type,
                                       median_type_descr,
                                       min_pavement_width_csl,
                                       min_struct_bridge_cond_csl,
                                       mpo,
                                       national_truck_network,
                                       national_truck_network_descr,
                                       nhs_status,
                                       nhs_type,
                                       nhs_type_descr,
                                       owner,
                                       owner_descr,
                                       pavement_condition_csl,
                                       pavement_rutting_csl,
                                       pavement_width_csl,
                                       pcr,
                                       plow_crew,
                                       pms_file_name,
                                       pms_inventory_year,
                                       priority,
                                       ride_quality_csl,
                                       right_rut,
                                       right_turn_lane_count,
                                       right_turn_lane_width,
                                       roadway_strength_csl,
                                       roadway_type,
                                       roadway_type_descr,
                                       road_posting_csl,
                                       rut_csl,
                                       safety_csl,
                                       scenic_byway_description,
                                       scenic_byway_desig_yr,
                                       scenic_byway_name,
                                       scenic_byway_type,
                                       scenic_byway_type_descr,
                                       section_length,
                                       service_csl,
                                       sh_sa_ir_designation,
                                       speed,
                                       speedsrc,
                                       speedzn_id,
                                       spur_number,
                                       state_aid_no,
                                       state_designation_number,
                                       state_desig_type,
                                       state_desig_type_descr,
                                       state_highway_designation_number,
                                       state_urban_rural,
                                       state_urban_rural_descr,
                                       strategic_highway_network,
                                       strategic_highway_network_desc,
                                       street_name,
                                       street_name_prefix,
                                       street_name_suffix,
                                       struct_bridge_cond_csl,
                                       summer_crew,
                                       thru_lane_count,
                                       thru_lane_width,
                                       total_pavement_width,
                                       truck_lane_count,
                                       truck_lane_width,
                                       truck_percent,
                                       wcsh_code,
                                       wcsh_agreement,
                                       weighted_iri_csl,
                                       weighted_pcr_csl,
                                       width,
                                       winter_crew)
             VALUES (  convert_to_number (l_aadt),
                       l_aadt_type,
                       l_aadt_type_descr,
                       convert_to_number (l_aadt_year),
                       l_abn,
                       l_abn_descr,
                       convert_to_number (l_access_control),
                       l_access_control_descr,
                       l_agency,
                       l_agency_descr,
                       convert_to_number (l_begin_offset),
                       l_bridge_posting_csl,
                       l_bridge_reliability_csl,
                       convert_to_number (l_capacity),
                       convert_to_number (l_center_turn_lane_count),
                       convert_to_number (l_center_turn_lane_width),
                       l_condition_csl,
                       l_congestion_csl,
                       convert_to_number (l_congestion_rate_csl),
                       l_crash_history_csl,
                       l_crash_history_rate_csl,
                       convert_to_number (l_csl_year),
                       convert_to_number (l_element_id),
                       ele_wid,
                       convert_to_number (l_end_offset),
                       convert_to_number (l_factored_aadt),
                       convert_to_number (l_factor_year),
                       convert_to_number (l_federal_functional_class),
                       l_federal_functional_class_descr,
                       l_federal_urban_group,
                       l_federal_urban_group_descr,
                       l_federal_urban_rural,
                       l_federal_urban_rural_descr,
                       convert_to_number (l_future_adt),
                       convert_to_number (l_future_adt_year),
                       l_hass_description,
                       convert_to_number (l_hass_id),
                       l_hpms_section_id,
                        hmvm, --                          HUNDRED_MILLION_VEHICLE_MILES,
                       convert_to_number (l_iri),
                       l_jurisdiction,
                       l_jurisdiction_abbreviation,
                       convert_to_number (l_jurisdiction_code),
                       convert_to_number (l_lane_count),
                       convert_to_number (l_lane_surface_type),
                       l_lane_surface_type_descr,
                       convert_to_number (l_left_rut),
                       convert_to_number (l_left_turn_lane_count),
                       convert_to_number (l_left_turn_lane_width),
                       l_maint_resp_winter,
                       l_maint_resp_winter_descr,
                       l_maint_resp_yearround,
                       l_maint_resp_year_descr,
                       convert_to_number (l_mean_sum_deflection_csl),
                       convert_to_number (l_median_average_width),
                       l_median_type,
                       l_median_type_descr,
                       convert_to_number (l_min_pavement_width_csl),
                       convert_to_number (l_min_struct_bridge_cond_csl),
                       l_mpo,
                       l_national_truck_network,
                       l_national_truck_network_descr,
                       l_nhs_status,
                       convert_to_number (l_nhs_type),
                       l_nhs_type_descr,
                       l_owner,
                       l_owner_descr,
                       l_pavement_condition_csl,
                       l_pavement_rutting_csl,
                       l_pavement_width_csl,
                       convert_to_number (l_pcr),
                       l_plow_crew,
                       l_pms_file_name,
                       convert_to_number (l_pms_inventory_year),
                       convert_to_number (l_priority),
                        l_ride_quality_csl,
                       convert_to_number (l_right_rut),
                       convert_to_number (l_right_turn_lane_count),
                       convert_to_number (l_right_turn_lane_width),
                       l_roadway_strength_csl,
                       l_roadway_type,
                       l_roadway_type_descr,
                       l_road_posting_csl,
                       convert_to_number (l_rut_csl),
                        l_safety_csl,
                       l_scenic_byway_description,
                       convert_to_number (l_scenic_byway_desig_yr),
                       l_scenic_byway_name,
                       l_scenic_byway_type,
                       l_scenic_byway_type_descr,
                       section_len,
                       l_service_csl,
                       l_sh_sa_ir_designation,
                       convert_to_number (l_speed),
                       l_speedsrc,
                       convert_to_number (l_speedzn_id),
                       l_spur_number,
                       l_state_aid_no,
                       l_state_designation_number,
                       l_state_desig_type,
                       l_state_desig_type_descr,
                       l_state_hwy_designation_number,
                       l_state_urban_rural,
                       l_state_urban_rural_descr,
                       convert_to_number (l_strategic_highway_network),
                       l_strategic_highway_network_desc,
                       l_street_name,
                       l_street_name_prefix,
                       l_street_name_suffix,
                       l_struct_bridge_cond_csl,
                       l_summer_crew,
                       convert_to_number (l_thru_lane_count),
                       convert_to_number (l_thru_lane_width),
                       convert_to_number (l_total_pavement_width),
                       convert_to_number (l_truck_lane_count),
                       convert_to_number (l_truck_lane_width),
                       convert_to_number (l_truck_percent),
                       l_wcsh_code,
                       l_wcsh_agreement,
                       convert_to_number (l_weighted_iri_csl),
                       convert_to_number (l_weighted_pcr_csl),
                       convert_to_number (l_width),
                       l_winter_crew
                                   )
                LOG ERRORS INTO sections_staging_error_log
                        ('Insert Sections Staging2 ' || SYSDATE)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;
EXCEPTION 
WHEN NO_DATA_FOUND THEN 
DBMS_OUTPUT.PUT_LINE(' Procedure Failed' );

WHEN OTHERS THEN
DBMS_OUTPUT.PUT_LINE('UNEXPECTED ERROR: '  || TO_CHAR(SQLCODE) || ' ' || SUBSTR(SQLERRM, 1,100));
DBMS_OUTPUT.PUT_LINE('Route number : ' || l_route_number || ' Begin section mp ' ||
                     l_begin_section_mp || ' end section mp ' ||
                     l_end_section_mp || ' Element ' || l_element_id );

END;
/
