CREATE OR REPLACE PROCEDURE load_complete_network
IS
    /**********************************************************************
    This procedure loads the COMPLETE_TRANSPORTATION_NETWORK table which is a combination (UNION) of
    route_sections with nodes from the view V_COMPLETE_NETWORK

    The COMPLETE_TRANSPORTATION_NETWORK is the table used by the views for the obiee highway model and crash model

    It truncates the partition for the current snapshot year, and re-loads it.
    This is run weekly

    04-16-2019 SH  Initial Version

    10-04-19 SH  Add snapshot year, partition by the snapshot_year, truncate and reload current
                 partition only
    10-07-19 SH Mark index partition unusable
    01-06-20 SH Fix bug in order of passing parameters to MARK_INDEX_PARTITION_UNUSABLE
    03-03-20 SH Get latest snapshot year from ELEMENTS_HISTORY table rather than COMPLETE_TRANSPORTATION_NETWORK so the same code
                will work to create the next snapshot year once ELEMENTS has been snapshot
    04-30-20 SH Add street_seqno which is the relative ordering of the streets starting at the begin mile-point of the route.
                It is computed for the primary numbered and inventory routes
    05-08-20 SH Compute street_seqno for alternate numbered and inventory routes also
    05-27-20 SH Break on jurisdiction when computing street_seqno
    06-02-20 SH Add columns ga_type, ga_type_descr
    07-06-20 SH Add sidewalks
    06-16-21 SH Add columns FED_AID, LAST_TREATMENT_PSN
    02-27-24 DG  Add columns BASE_AS_BUILT_HMA, BASE_GRAN_THICK, BASE_GRAN_TYPE, BASE_GRAN_TYPE_DESCR, BASE_MISC_THICK, BASE_MISC_TYPE, BASE_MISC_TYPE_DESCR, 
                             BASE_MOD_TYPE, BASE_MOD_TYPE_DESCR, BASE_MOD_YR, BASE_PRI_ID_TYPE, BASE_PRI_ID_TYPE_DESCR, BASE_PRIMARY_ID, BASE_PRIMARY_WIN,                
                             BASE_SEC_ID_TYPE, BASE_SEC_ID_TYPE_DESCR, BASE_SECOND_ID, BASE_SUB_THICK, 
                             EXCEPTIONS_DESC_XXX, FACTORED_AADT_CALC_COMMENT, 
                             HPMT_COMB_AADT_PCNT, HPMT_COMB_DHV_PCNT, HPMT_DHV_PCNT, HPMT_DIR_DIST, HPMT_PASS_AADT_PCNTc, HPMT_PASS_DHV_PCNT, HPMT_SU_AADT_PCNT, HPMT_SU_DHV_PCNT
                             NHFN_CONNECTOR_ID, NHFN_SUBSYSTEM, NHFN_SUBSYSTEM_DESCR, SLD_FILE_DATE, SLD_FILE_NAME 
    **********************************************************************/



    commit_count         NUMBER (7) := 0;
    cntr                 NUMBER (7) := 0;

    g_start_time         DATE := SYSDATE;
    g_owner              VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname            VARCHAR2 (30) := 'LOAD_COMPLETE_NETWORK';
    g_object             VARCHAR2 (20) := 'COMPLETE_NETWORK';
    g_sqlmsg             VARCHAR2 (500) := NULL;

    last_snapshot_year   NUMBER;

    current_partition    VARCHAR2 (20);

    seqno                NUMBER := 0;

    CURSOR ctn
    IS
        SELECT AADT,
               AADT_TYPE,
               AADT_TYPE_DESCR,
               AADT_YEAR,
               ABN,
               ABN_DESCR,
               ACCESS_CONTROL,
               ACCESS_CONTROL_DESCR,
               AGENCY,
               AGENCY_DESCR,
               BASE_AS_BUILT_HMA,        
               BASE_GRAN_THICK,
               BASE_GRAN_TYPE,
               BASE_GRAN_TYPE_DESCR,
               BASE_MISC_THICK,                 
               BASE_MISC_TYPE,                  
               BASE_MISC_TYPE_DESCR,            
               BASE_MOD_TYPE,                   
               BASE_MOD_TYPE_DESCR,             
               BASE_MOD_YR,                     
               BASE_PRI_ID_TYPE,                
               BASE_PRI_ID_TYPE_DESCR,          
               BASE_PRIMARY_ID,                 
               BASE_PRIMARY_WIN,                
               BASE_SEC_ID_TYPE,                
               BASE_SEC_ID_TYPE_DESCR,          
               BASE_SECOND_ID,                  
               BASE_SUB_THICK,  
               BEGIN_ELEMENT_MILEPOINT,
               BEGIN_NODE_DESCRIPTION,
               BEGIN_NODE_ID,
               BEGIN_SECTION_MP,
               BEGIN_SECTION_OFFSET,
               BRIDGE_POSTING_CSL,
               BRIDGE_RELIABILITY_CSL,
               CAPACITY,
               CENTER_TURN_LANE_COUNT,
               CENTER_TURN_LANE_WIDTH,
               CONDITION_CSL,
               CONGESTION_CSL,
               CONGESTION_RATE_CSL,
               COUNTY_CODE,
               COUNTY_NAME,
               CRASH_HISTORY_CSL,
               CRASH_HISTORY_RATE_CSL,
               CSL_YEAR,
               CUMULATIVE_MILEPOINT_ORDER,
               DIRECTION,
               DIRECTIONAL_SUFFIX,
               ELEMENT_ID,
               ELEMENT_LENGTH,
               ELEMENT_WID,
               END_ELEMENT_MILEPOINT,
               END_NODE_DESCRIPTION,
               END_NODE_ID,
               END_SECTION_MP,
               END_SECTION_OFFSET,
               EXCEPTIONS_DESC_XXX,
               EXISTING,
               FACTORED_AADT,
               FACTORED_AADT_CALC_COMMENT,
               FACTOR_GROUP,
               FACTOR_YEAR,
               FED_AID,
               FEDERAL_FUNCTIONAL_CLASS,
               FEDERAL_FUNCTIONAL_CLASS_DESCR,
               FEDERAL_URBAN_GROUP,
               FEDERAL_URBAN_GROUP_DESCR,
               FEDERAL_URBAN_RURAL,
               FEDERAL_URBAN_RURAL_DESCR,
               FUTURE_ADT,
               FUTURE_ADT_YEAR,
               GA_TYPE,
               GA_TYPE_DESCR,
               HASS_DESCRIPTION,
               HASS_ID,
               HPMS_SECTION_ID,
               HPMT_COMB_AADT_PCNT,
               HPMT_COMB_DHV_PCNT,
               HPMT_DHV_PCNT,
               HPMT_DIR_DIST,
               HPMT_PASS_AADT_PCNT,
               HPMT_PASS_DHV_PCNT,
               HPMT_SU_AADT_PCNT,
               HPMT_SU_DHV_PCNT,
               HUNDRED_MILLION_VEHICLE_MILES,
               IRI,
               JURISDICTION,
               JURISDICTION_ABBREVIATION,
               JURISDICTION_CODE,
               LANE_COUNT,
               LANE_SURFACE_TYPE,
               LANE_SURFACE_TYPE_DESCR,
               LAST_TREATMENT_PSN,
               LEFT_LANE_CROSSSECTION,
               LEFT_RUT,
               LEFT_SHOULDER_TYPE,
               LEFT_SHOULDER_TYPE_DESCR,
               LEFT_SHOULDER_WIDTH,
               LEFT_SIDEWALK_TYPE,
               LEFT_SIDEWALK_TYPE_DESCR,
               LEFT_SIDEWALK_WIDTH,
               LEFT_TURN_LANE_COUNT,
               LEFT_TURN_LANE_WIDTH,
               MAINTENANCE_REGION,
               MAINTENANCE_REGION_DESCR,
               MAINT_RESP_WINTER,
               MAINT_RESP_WINTER_DESCR,
               MAINT_RESP_YEARROUND,
               MAINT_RESP_YEAR_DESCR,
               MEAN_SUM_DEFLECTION_CSL,
               MEDIAN_AVERAGE_WIDTH,
               MEDIAN_TYPE,
               MEDIAN_TYPE_DESCR,
               MEV,
               MIN_PAVEMENT_WIDTH_CSL,
               MIN_STRUCT_BRIDGE_COND_CSL,
               MPO,
               NATIONAL_TRUCK_NETWORK,
               NATIONAL_TRUCK_NETWORK_DESCR,
               NHFN_CONNECTOR_ID,
               NHFN_SUBSYSTEM,
               NHFN_SUBSYSTEM_DESCR,
               NHS_STATUS,
               NHS_TYPE,
               NHS_TYPE_DESCR,
               NODE_DESCRIPTION,
               NODE_ID,
               NO_OF_LEGS,
               NUMBER_OF_LANES,
               OFFICIAL_MILES,
               ONE_WAY,
               ONE_WAY_DESCR,
               OWNER,
               OWNER_DESCR,
               PAVEMENT_CONDITION_CSL,
               PAVEMENT_RUTTING_CSL,
               PAVEMENT_WIDTH_CSL,
               PCR,
               PLOW_CREW,
               PMS_FILE_NAME,
               PMS_INVENTORY_YEAR,
               PRIMARY,
               PRIMARY_ROUTE_MP,
               PRIMARY_ROUTE_NUMBER,
               PRIORITY,
               RAMP,
               RAMP_DESCR,
               RIDE_QUALITY_CSL,
               RIGHT_LANE_CROSSSECTION,
               RIGHT_RUT,
               RIGHT_SHOULDER_TYPE,
               RIGHT_SHOULDER_TYPE_DESCR,
               RIGHT_SHOULDER_WIDTH,
               RIGHT_SIDEWALK_TYPE,
               RIGHT_SIDEWALK_TYPE_DESCR,
               RIGHT_SIDEWALK_WIDTH,
               RIGHT_TURN_LANE_COUNT,
               RIGHT_TURN_LANE_WIDTH,
               ROADWAY_STRENGTH_CSL,
               ROADWAY_TYPE,
               ROADWAY_TYPE_DESCR,
               ROAD_POSTING_CSL,
               ROUTE_GROUP,
               ROUTE_NAME,
               ROUTE_NUMBER,
               ROUTE_SYSTEM,
               ROUTE_TYPE,
               ROW_TYPE,
               RUT_CSL,
               SAFETY_CSL,
               SCENIC_BYWAY_DESCRIPTION,
               SCENIC_BYWAY_DESIG_YR,
               SCENIC_BYWAY_NAME,
               SCENIC_BYWAY_TYPE,
               SCENIC_BYWAY_TYPE_DESCR,
               SECTION_ID,
               SECTION_LENGTH,
               SERVICE_CSL,
               SH_SA_IR_DESIGNATION,
               SLD_FILE_DATE, 
               SLD_FILE_NAME, 
               SORTORD,
               SPEED,
               SPEEDSRC,
               SPEEDZN_ID,
               SPUR_NUMBER,
               STATE_AID_NO,
               STATE_DESIGNATION_NUMBER,
               STATE_DESIG_TYPE,
               STATE_DESIG_TYPE_DESCR,
               STATE_HIGHWAY_DESIGNATION_NUMBER,
               STATE_URBAN_RURAL,
               STATE_URBAN_RURAL_DESCR,
               STRATEGIC_HIGHWAY_NETWORK,
               STRATEGIC_HIGHWAY_NETWORK_DESC,
               STREETNAME,
               STREET_NAME,
               STREET_NAME_PREFIX,
               STREET_NAME_SUFFIX,
               STRUCT_BRIDGE_COND_CSL,
               SUMMER_CREW,
               THRU_LANE_COUNT,
               THRU_LANE_WIDTH,
               TOTAL_PAVEMENT_WIDTH,
               TOWNLINE_NODE,
               TOWN_CODE,
               TOWN_NAME,
               TRAFFIC_SIGNAL,
               TRANSPORTATION_MODE,
               TRUCK_LANE_COUNT,
               TRUCK_LANE_WIDTH,
               TRUCK_PERCENT,
               WCSH_AGREEMENT,
               WCSH_CODE,
               WEIGHTED_IRI_CSL,
               WEIGHTED_PCR_CSL,
               WIDTH,
               WINTER_CREW
          FROM v_complete_network;

    CURSOR aroutes
    IS
          SELECT route_number,
                 town_name,
                 jurisdiction,
                 element_id,
                 section_id,
                 begin_section_mp,
                 streetname,
                 LAG (streetname)
                     OVER (ORDER BY route_number, begin_section_mp)
                     AS prev_street,
                 LAG (route_number)
                     OVER (ORDER BY route_number, begin_section_mp)
                     AS prev_route,
                 LAG (jurisdiction)
                     OVER (ORDER BY route_number, begin_section_mp)
                     AS prev_jurisdiction
            FROM complete_transportation_network
           WHERE     route_type IN ('N', 'I')
                 AND snapshot_year = last_snapshot_year
                 AND row_type = 'Element'
        ORDER BY route_number, begin_section_mp;


    rec                  aroutes%ROWTYPE;


    PROCEDURE write_it
    IS
    BEGIN
        UPDATE complete_transportation_network c
           SET street_seqno = SEQNO
         WHERE     c.section_id = REC.section_id
               AND c.route_number = REC.route_number;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END;
BEGIN
    SELECT MAX (snapshot_year) INTO last_snapshot_year FROM element_history;

    current_partition := 'COMP_TRANSP_NET_' || last_snapshot_year;


    EXECUTE IMMEDIATE
           'ALTER TABLE COMPLETE_TRANSPORTATION_NETWORK TRUNCATE PARTITION '
        || CURRENT_PARTITION;

    EXECUTE IMMEDIATE 'TRUNCATE TABLE COMPLETE_NETWORK_ERROR_LOG';

    MANAGE_INDEXES.Mark_Indexes_Unusable ('COMPLETE_TRANSPORTATION_NETWORK');

    MANAGE_INDEXES.MARK_INDEX_PARTITION_UNUSABLE (
        'COMPLETE_TRANSPORTATION_NETWORK',
        CURRENT_PARTITION);



    FOR C IN ctn
    LOOP
        INSERT INTO COMPLETE_TRANSPORTATION_NETWORK (
                        AADT,
                        AADT_TYPE,
                        AADT_TYPE_DESCR,
                        AADT_YEAR,
                        ABN,
                        ABN_DESCR,
                        ACCESS_CONTROL,
                        ACCESS_CONTROL_DESCR,
                        AGENCY,
                        AGENCY_DESCR,
                        BASE_AS_BUILT_HMA,        
                        BASE_GRAN_THICK,
                        BASE_GRAN_TYPE,
                        BASE_GRAN_TYPE_DESCR,
                        BASE_MISC_THICK,                 
                        BASE_MISC_TYPE,                  
                        BASE_MISC_TYPE_DESCR,            
                        BASE_MOD_TYPE,                   
                        BASE_MOD_TYPE_DESCR,             
                        BASE_MOD_YR,                     
                        BASE_PRI_ID_TYPE,                
                        BASE_PRI_ID_TYPE_DESCR,          
                        BASE_PRIMARY_ID,                 
                        BASE_PRIMARY_WIN,                
                        BASE_SEC_ID_TYPE,                
                        BASE_SEC_ID_TYPE_DESCR,          
                        BASE_SECOND_ID,                  
                        BASE_SUB_THICK,  
                        BEGIN_ELEMENT_MILEPOINT,
                        BEGIN_NODE_DESCRIPTION,
                        BEGIN_NODE_ID,
                        BEGIN_SECTION_MP,
                        BEGIN_SECTION_OFFSET,
                        BRIDGE_POSTING_CSL,
                        BRIDGE_RELIABILITY_CSL,
                        CAPACITY,
                        CENTER_TURN_LANE_COUNT,
                        CENTER_TURN_LANE_WIDTH,
                        CONDITION_CSL,
                        CONGESTION_CSL,
                        CONGESTION_RATE_CSL,
                        COUNTY_CODE,
                        COUNTY_NAME,
                        CRASH_HISTORY_CSL,
                        CRASH_HISTORY_RATE_CSL,
                        CSL_YEAR,
                        CUMULATIVE_MILEPOINT_ORDER,
                        DIRECTION,
                        DIRECTIONAL_SUFFIX,
                        ELEMENT_ID,
                        ELEMENT_LENGTH,
                        ELEMENT_WID,
                        END_ELEMENT_MILEPOINT,
                        END_NODE_DESCRIPTION,
                        END_NODE_ID,
                        END_SECTION_MP,
                        END_SECTION_OFFSET,
                        EXCEPTIONS_DESC_XXX,
                        EXISTING,
                        FACTORED_AADT,
                        FACTORED_AADT_CALC_COMMENT,
                        FACTOR_GROUP,
                        FACTOR_YEAR,
                        FED_AID,
                        FEDERAL_FUNCTIONAL_CLASS,
                        FEDERAL_FUNCTIONAL_CLASS_DESCR,
                        FEDERAL_URBAN_GROUP,
                        FEDERAL_URBAN_GROUP_DESCR,
                        FEDERAL_URBAN_RURAL,
                        FEDERAL_URBAN_RURAL_DESCR,
                        FUTURE_ADT,
                        FUTURE_ADT_YEAR,
                        GA_TYPE,
                        GA_TYPE_DESCR,
                        HASS_DESCRIPTION,
                        HASS_ID,
                        HPMS_SECTION_ID,
                        HPMT_COMB_AADT_PCNT,
                        HPMT_COMB_DHV_PCNT,
                        HPMT_DHV_PCNT,
                        HPMT_DIR_DIST,
                        HPMT_PASS_AADT_PCNT,
                        HPMT_PASS_DHV_PCNT,
                        HPMT_SU_AADT_PCNT,
                        HPMT_SU_DHV_PCNT,
                        HUNDRED_MILLION_VEHICLE_MILES,
                        IRI,
                        JURISDICTION,
                        JURISDICTION_ABBREVIATION,
                        JURISDICTION_CODE,
                        LANE_COUNT,
                        LANE_SURFACE_TYPE,
                        LANE_SURFACE_TYPE_DESCR,
                        LAST_TREATMENT_PSN,
                        LEFT_LANE_CROSSSECTION,
                        LEFT_RUT,
                        LEFT_SHOULDER_TYPE,
                        LEFT_SHOULDER_TYPE_DESCR,
                        LEFT_SHOULDER_WIDTH,
                        LEFT_SIDEWALK_TYPE,
                        LEFT_SIDEWALK_TYPE_DESCR,
                        LEFT_SIDEWALK_WIDTH,
                        LEFT_TURN_LANE_COUNT,
                        LEFT_TURN_LANE_WIDTH,
                        MAINTENANCE_REGION,
                        MAINTENANCE_REGION_DESCR,
                        MAINT_RESP_WINTER,
                        MAINT_RESP_WINTER_DESCR,
                        MAINT_RESP_YEARROUND,
                        MAINT_RESP_YEAR_DESCR,
                        MEAN_SUM_DEFLECTION_CSL,
                        MEDIAN_AVERAGE_WIDTH,
                        MEDIAN_TYPE,
                        MEDIAN_TYPE_DESCR,
                        MEV,
                        MIN_PAVEMENT_WIDTH_CSL,
                        MIN_STRUCT_BRIDGE_COND_CSL,
                        MPO,
                        NATIONAL_TRUCK_NETWORK,
                        NATIONAL_TRUCK_NETWORK_DESCR,
                        NHFN_CONNECTOR_ID,
                        NHFN_SUBSYSTEM,
                        NHFN_SUBSYSTEM_DESCR,
                        NHS_STATUS,
                        NHS_TYPE,
                        NHS_TYPE_DESCR,
                        NODE_DESCRIPTION,
                        NODE_ID,
                        NO_OF_LEGS,
                        NUMBER_OF_LANES,
                        OFFICIAL_MILES,
                        ONE_WAY,
                        ONE_WAY_DESCR,
                        OWNER,
                        OWNER_DESCR,
                        PAVEMENT_CONDITION_CSL,
                        PAVEMENT_RUTTING_CSL,
                        PAVEMENT_WIDTH_CSL,
                        PCR,
                        PLOW_CREW,
                        PMS_FILE_NAME,
                        PMS_INVENTORY_YEAR,
                        PRIMARY,
                        PRIMARY_ROUTE_MP,
                        PRIMARY_ROUTE_NUMBER,
                        PRIORITY,
                        RAMP,
                        RAMP_DESCR,
                        RIDE_QUALITY_CSL,
                        RIGHT_LANE_CROSSSECTION,
                        RIGHT_RUT,
                        RIGHT_SHOULDER_TYPE,
                        RIGHT_SHOULDER_TYPE_DESCR,
                        RIGHT_SHOULDER_WIDTH,
                        RIGHT_SIDEWALK_TYPE,
                        RIGHT_SIDEWALK_TYPE_DESCR,
                        RIGHT_SIDEWALK_WIDTH,
                        RIGHT_TURN_LANE_COUNT,
                        RIGHT_TURN_LANE_WIDTH,
                        ROADWAY_STRENGTH_CSL,
                        ROADWAY_TYPE,
                        ROADWAY_TYPE_DESCR,
                        ROAD_POSTING_CSL,
                        ROUTE_GROUP,
                        ROUTE_NAME,
                        ROUTE_NUMBER,
                        ROUTE_SYSTEM,
                        ROUTE_TYPE,
                        ROW_TYPE,
                        RUT_CSL,
                        SAFETY_CSL,
                        SCENIC_BYWAY_DESCRIPTION,
                        SCENIC_BYWAY_DESIG_YR,
                        SCENIC_BYWAY_NAME,
                        SCENIC_BYWAY_TYPE,
                        SCENIC_BYWAY_TYPE_DESCR,
                        SECTION_ID,
                        SECTION_LENGTH,
                        SERVICE_CSL,
                        SH_SA_IR_DESIGNATION,
                        SLD_FILE_DATE, 
                        SLD_FILE_NAME, 
                        SNAPSHOT_YEAR,
                        SORTORD,
                        SPEED,
                        SPEEDSRC,
                        SPEEDZN_ID,
                        SPUR_NUMBER,
                        STATE_AID_NO,
                        STATE_DESIGNATION_NUMBER,
                        STATE_DESIG_TYPE,
                        STATE_DESIG_TYPE_DESCR,
                        STATE_HIGHWAY_DESIGNATION_NUMBER,
                        STATE_URBAN_RURAL,
                        STATE_URBAN_RURAL_DESCR,
                        STRATEGIC_HIGHWAY_NETWORK,
                        STRATEGIC_HIGHWAY_NETWORK_DESC,
                        STREETNAME,
                        STREET_NAME,
                        STREET_NAME_PREFIX,
                        STREET_NAME_SUFFIX,
                        STRUCT_BRIDGE_COND_CSL,
                        SUMMER_CREW,
                        THRU_LANE_COUNT,
                        THRU_LANE_WIDTH,
                        TOTAL_PAVEMENT_WIDTH,
                        TOWNLINE_NODE,
                        TOWN_CODE,
                        TOWN_NAME,
                        TRAFFIC_SIGNAL,
                        TRANSPORTATION_MODE,
                        TRUCK_LANE_COUNT,
                        TRUCK_LANE_WIDTH,
                        TRUCK_PERCENT,
                        WCSH_AGREEMENT,
                        WCSH_CODE,
                        WEIGHTED_IRI_CSL,
                        WEIGHTED_PCR_CSL,
                        WIDTH,
                        WINTER_CREW)
             VALUES (C.AADT,
                     C.AADT_TYPE,
                     C.AADT_TYPE_DESCR,
                     C.AADT_YEAR,
                     C.ABN,
                     C.ABN_DESCR,
                     C.ACCESS_CONTROL,
                     C.ACCESS_CONTROL_DESCR,
                     C.AGENCY,
                     C.AGENCY_DESCR,
                     C.BASE_AS_BUILT_HMA,        
                     C.BASE_GRAN_THICK,
                     C.BASE_GRAN_TYPE,
                     C.BASE_GRAN_TYPE_DESCR,
                     C.BASE_MISC_THICK,                 
                     C.BASE_MISC_TYPE,                  
                     C.BASE_MISC_TYPE_DESCR,            
                     C.BASE_MOD_TYPE,                   
                     C.BASE_MOD_TYPE_DESCR,             
                     C.BASE_MOD_YR,                     
                     C.BASE_PRI_ID_TYPE,                
                     C.BASE_PRI_ID_TYPE_DESCR,          
                     C.BASE_PRIMARY_ID,                 
                     C.BASE_PRIMARY_WIN,                
                     C.BASE_SEC_ID_TYPE,                
                     C.BASE_SEC_ID_TYPE_DESCR,          
                     C.BASE_SECOND_ID,                  
                     C.BASE_SUB_THICK,  
                     C.BEGIN_ELEMENT_MILEPOINT,
                     C.BEGIN_NODE_DESCRIPTION,
                     C.BEGIN_NODE_ID,
                     C.BEGIN_SECTION_MP,
                     C.BEGIN_SECTION_OFFSET,
                     C.BRIDGE_POSTING_CSL,
                     C.BRIDGE_RELIABILITY_CSL,
                     C.CAPACITY,
                     C.CENTER_TURN_LANE_COUNT,
                     C.CENTER_TURN_LANE_WIDTH,
                     C.CONDITION_CSL,
                     C.CONGESTION_CSL,
                     C.CONGESTION_RATE_CSL,
                     C.COUNTY_CODE,
                     C.COUNTY_NAME,
                     C.CRASH_HISTORY_CSL,
                     C.CRASH_HISTORY_RATE_CSL,
                     C.CSL_YEAR,
                     C.CUMULATIVE_MILEPOINT_ORDER,
                     C.DIRECTION,
                     C.DIRECTIONAL_SUFFIX,
                     C.ELEMENT_ID,
                     C.ELEMENT_LENGTH,
                     C.ELEMENT_WID,
                     C.END_ELEMENT_MILEPOINT,
                     C.END_NODE_DESCRIPTION,
                     C.END_NODE_ID,
                     C.END_SECTION_MP,
                     C.END_SECTION_OFFSET,
                     C.EXCEPTIONS_DESC_XXX,
                     C.EXISTING,
                     C.FACTORED_AADT,
                     C.FACTORED_AADT_CALC_COMMENT,
                     C.FACTOR_GROUP,
                     C.FACTOR_YEAR,
                     C.FED_AID,
                     C.FEDERAL_FUNCTIONAL_CLASS,
                     C.FEDERAL_FUNCTIONAL_CLASS_DESCR,
                     C.FEDERAL_URBAN_GROUP,
                     C.FEDERAL_URBAN_GROUP_DESCR,
                     C.FEDERAL_URBAN_RURAL,
                     C.FEDERAL_URBAN_RURAL_DESCR,
                     C.FUTURE_ADT,
                     C.FUTURE_ADT_YEAR,
                     C.GA_TYPE,
                     C.GA_TYPE_DESCR,
                     C.HASS_DESCRIPTION,
                     C.HASS_ID,
                     C.HPMS_SECTION_ID,
                     C.HPMT_COMB_AADT_PCNT,
                     C.HPMT_COMB_DHV_PCNT,
                     C.HPMT_DHV_PCNT,
                     C.HPMT_DIR_DIST,
                     C.HPMT_PASS_AADT_PCNT,
                     C.HPMT_PASS_DHV_PCNT,
                     C.HPMT_SU_AADT_PCNT,
                     C.HPMT_SU_DHV_PCNT,
                     C.HUNDRED_MILLION_VEHICLE_MILES,
                     C.IRI,
                     C.JURISDICTION,
                     C.JURISDICTION_ABBREVIATION,
                     C.JURISDICTION_CODE,
                     C.LANE_COUNT,
                     C.LANE_SURFACE_TYPE,
                     C.LANE_SURFACE_TYPE_DESCR,
                     C.LAST_TREATMENT_PSN,
                     C.LEFT_LANE_CROSSSECTION,
                     C.LEFT_RUT,
                     C.LEFT_SHOULDER_TYPE,
                     C.LEFT_SHOULDER_TYPE_DESCR,
                     C.LEFT_SHOULDER_WIDTH,
                     C.LEFT_SIDEWALK_TYPE,
                     C.LEFT_SIDEWALK_TYPE_DESCR,
                     C.LEFT_SIDEWALK_WIDTH,
                     C.LEFT_TURN_LANE_COUNT,
                     C.LEFT_TURN_LANE_WIDTH,
                     C.MAINTENANCE_REGION,
                     C.MAINTENANCE_REGION_DESCR,
                     C.MAINT_RESP_WINTER,
                     C.MAINT_RESP_WINTER_DESCR,
                     C.MAINT_RESP_YEARROUND,
                     C.MAINT_RESP_YEAR_DESCR,
                     C.MEAN_SUM_DEFLECTION_CSL,
                     C.MEDIAN_AVERAGE_WIDTH,
                     C.MEDIAN_TYPE,
                     C.MEDIAN_TYPE_DESCR,
                     C.MEV,
                     C.MIN_PAVEMENT_WIDTH_CSL,
                     C.MIN_STRUCT_BRIDGE_COND_CSL,
                     C.MPO,
                     C.NATIONAL_TRUCK_NETWORK,
                     C.NATIONAL_TRUCK_NETWORK_DESCR,
                     C.NHFN_CONNECTOR_ID,
                     C.NHFN_SUBSYSTEM,
                     C.NHFN_SUBSYSTEM_DESCR,
                     C.NHS_STATUS,
                     C.NHS_TYPE,
                     C.NHS_TYPE_DESCR,
                     C.NODE_DESCRIPTION,
                     C.NODE_ID,
                     C.NO_OF_LEGS,
                     C.NUMBER_OF_LANES,
                     C.OFFICIAL_MILES,
                     C.ONE_WAY,
                     C.ONE_WAY_DESCR,
                     C.OWNER,
                     C.OWNER_DESCR,
                     C.PAVEMENT_CONDITION_CSL,
                     C.PAVEMENT_RUTTING_CSL,
                     C.PAVEMENT_WIDTH_CSL,
                     C.PCR,
                     C.PLOW_CREW,
                     C.PMS_FILE_NAME,
                     C.PMS_INVENTORY_YEAR,
                     C.PRIMARY,
                     C.PRIMARY_ROUTE_MP,
                     C.PRIMARY_ROUTE_NUMBER,
                     C.PRIORITY,
                     C.RAMP,
                     C.RAMP_DESCR,
                     C.RIDE_QUALITY_CSL,
                     C.RIGHT_LANE_CROSSSECTION,
                     C.RIGHT_RUT,
                     C.RIGHT_SHOULDER_TYPE,
                     C.RIGHT_SHOULDER_TYPE_DESCR,
                     C.RIGHT_SHOULDER_WIDTH,
                     C.RIGHT_SIDEWALK_TYPE,
                     C.RIGHT_SIDEWALK_TYPE_DESCR,
                     C.RIGHT_SIDEWALK_WIDTH,
                     C.RIGHT_TURN_LANE_COUNT,
                     C.RIGHT_TURN_LANE_WIDTH,
                     C.ROADWAY_STRENGTH_CSL,
                     C.ROADWAY_TYPE,
                     C.ROADWAY_TYPE_DESCR,
                     C.ROAD_POSTING_CSL,
                     C.ROUTE_GROUP,
                     C.ROUTE_NAME,
                     C.ROUTE_NUMBER,
                     C.ROUTE_SYSTEM,
                     C.ROUTE_TYPE,
                     C.ROW_TYPE,
                     C.RUT_CSL,
                     C.SAFETY_CSL,
                     C.SCENIC_BYWAY_DESCRIPTION,
                     C.SCENIC_BYWAY_DESIG_YR,
                     C.SCENIC_BYWAY_NAME,
                     C.SCENIC_BYWAY_TYPE,
                     C.SCENIC_BYWAY_TYPE_DESCR,
                     C.SECTION_ID,
                     C.SECTION_LENGTH,
                     C.SERVICE_CSL,
                     C.SH_SA_IR_DESIGNATION,
                     C.SLD_FILE_DATE, 
                     C.SLD_FILE_NAME, 
                     last_snapshot_year,
                     C.SORTORD,
                     C.SPEED,
                     C.SPEEDSRC,
                     C.SPEEDZN_ID,
                     C.SPUR_NUMBER,
                     C.STATE_AID_NO,
                     C.STATE_DESIGNATION_NUMBER,
                     C.STATE_DESIG_TYPE,
                     C.STATE_DESIG_TYPE_DESCR,
                     C.STATE_HIGHWAY_DESIGNATION_NUMBER,
                     C.STATE_URBAN_RURAL,
                     C.STATE_URBAN_RURAL_DESCR,
                     C.STRATEGIC_HIGHWAY_NETWORK,
                     C.STRATEGIC_HIGHWAY_NETWORK_DESC,
                     C.STREETNAME,
                     C.STREET_NAME,
                     C.STREET_NAME_PREFIX,
                     C.STREET_NAME_SUFFIX,
                     C.STRUCT_BRIDGE_COND_CSL,
                     C.SUMMER_CREW,
                     C.THRU_LANE_COUNT,
                     C.THRU_LANE_WIDTH,
                     C.TOTAL_PAVEMENT_WIDTH,
                     C.TOWNLINE_NODE,
                     C.TOWN_CODE,
                     C.TOWN_NAME,
                     C.TRAFFIC_SIGNAL,
                     C.TRANSPORTATION_MODE,
                     C.TRUCK_LANE_COUNT,
                     C.TRUCK_LANE_WIDTH,
                     C.TRUCK_PERCENT,
                     C.WCSH_AGREEMENT,
                     C.WCSH_CODE,
                     C.WEIGHTED_IRI_CSL,
                     C.WEIGHTED_PCR_CSL,
                     C.WIDTH,
                     C.WINTER_CREW)
                LOG ERRORS INTO COMPLETE_NETWORK_ERROR_LOG
                        ('LOAD_COMPLETE_NETWORK ' || SYSDATE)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;

    MANAGE_INDEXES.Rebuild_Unusable_Indexes (
        'COMPLETE_TRANSPORTATION_NETWORK');

    -- Compute street sequence numbers
    OPEN aroutes;

    FETCH aroutes INTO rec;

    seqno := 1;                                        -- Process first record
    write_it;


    LOOP
        FETCH aroutes INTO rec;

        EXIT WHEN aroutes%NOTFOUND;

        IF rec.route_number = rec.prev_route                    -- same route?
        THEN
            IF rec.streetname = rec.prev_street                -- same street?
            THEN
                IF rec.jurisdiction <> rec.prev_jurisdiction -- same jurisdiction?
                THEN
                    seqno := seqno + 1;
                END IF;
            ELSE
                seqno := seqno + 1;                    -- we have a new street
            END IF;
        ELSE                                            -- we have a new route
            seqno := 1;
        END IF;

        write_it;
    END LOOP;

    COMMIT;

    CLOSE aroutes;

    SELECT COUNT (*) INTO cntr FROM COMPLETE_TRANSPORTATION_NETWORK;

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
