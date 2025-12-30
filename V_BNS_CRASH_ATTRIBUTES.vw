CREATE OR REPLACE VIEW WH_ASSETS.V_BNS_CRASH_ATTRIBUTES
BEQUEATH DEFINER
AS 
WITH
        oneelementsetup
        AS
            (SELECT element_id, node_id, offset, ROWNUM AS rn
               FROM (SELECT begin_node_id AS node_id, 0 AS offset, 'BEGIN' AS offset_type,
                            element_id
                       FROM elements
                     UNION
                     SELECT end_node_id AS node_id, element_length AS offset,
                            'END' AS offset_type, element_id
                       FROM elements)),
        minelement
        AS
            (  SELECT MIN (rn) AS min_rn, node_id
                 FROM oneelementsetup
             GROUP BY node_id),
        nodeaccidents
        AS
            (SELECT DISTINCT node_id
               FROM accidents
              WHERE element_id IS NULL AND node_id IS NOT NULL)
      SELECT a."ACCIDENT_DATE", a."ACCIDENT_DAY_OF_WEEK_NUM",
             a."ACCIDENT_DAY_OF_WEEK", a."ACCIDENT_TIME", a."ACCIDENT_YEAR", a.BICYCLE_YN,
             a."CONTRIB_CIRC_ENV1", a."CONTRIB_CIRC_ENV1_DESCR", a."CONTRIB_CIRC_ENV2",
             a."CONTRIB_CIRC_ENV2_DESCR", a."CONTRIB_CIRC_ROAD1", a."CONTRIB_CIRC_ROAD1_DESCR",
             a."CONTRIB_CIRC_ROAD2", a."CONTRIB_CIRC_ROAD2_DESCR", a."COUNTY_CODE",
             a."COUNTY_NAME", a."CRASH_COST", a."ELEMENT_ID", a."ELEMENT_WID", a."FARS_YN",
             a."INJURY_COUNT", a."LIGHT_CONDITION", a."LIGHT_CONDITION_DESCR",
             a."LOCATION_TYPE", a."LOC_FIRST_HARMFUL_EVENT", a."LOC_FIRST_HARMFUL_EVENT_DESCR",
             a."MDOTID", A."MOTORCYCLE_YN", a."NO_OF_A_INJ", a."NO_OF_B_INJ", a."NO_OF_C_INJ",
             a."NO_OF_K_INJ", a."NO_OF_NON_INJ", a."NODE_ID", a."OFFSET",
             a.PEDESTRIAN_YN AS PED_YN, a."REPORTING_AGENCY", a."REPORTING_AGENCY_DESCR",
             a."ROAD_SURF_COND", a."ROAD_SURF_COND_DESCR", a."ROAD_GRADE",
             a."ROAD_GRADE_DESCR", a."SECTION_ID", a."SCHOOL_BUS_RELATED",
             a."SCHOOL_BUS_RELATED_DESCR", a."TRAFFIC_CONTROL_DEVICE",
             a."TRAFFIC_CONTROL_DEVICE_DESCR", a."TYPE_OF_CRASH", a."TYPE_OF_CRASH_DESCR",
             a."TYPE_OF_LOCATION", a."TYPE_OF_LOCATION_DESCR", a."WEATHER_CONDITION",
             a."WEATHER_CONDITION_DESCR", a."WORKZONE_IN_OR_NEAR",
             a."WORKZONE_IN_OR_NEAR_DESCR", a."WORKZONE_LOCATION", a."WORKZONE_LOCATION_DESCR",
             a."WORKZONE_TYPE", a."WORKZONE_TYPE_DESCR", a."WORKZONE_WORKERS_PRESENT",
             a."WORKZONE_WORKERS_PRESENT_DESCR", a."WORKZONE_POLICE_PRESENT",
             a."WORKZONE_POLICE_PRESENT_DESCR",
             SUBSTR (a."PRIMARY_ROUTE_NUMBER", 1, 7) AS primary_route_number,
             a."PRIMARY_ROUTE_NAME", a."REPORT_NUMBER", a."LATITUDE", a."LONGITUDE",
             a."ACCIDENT_MONTH_NUM", a."ACCIDENT_MONTH_NAME", a."TOWN_CODE", a."TOWN_NAME",
             a."REGION_CODE", a."REGION_NAME", a."SPEED_LIMIT", a."FEDERAL_URBAN_GROUP",
             a."FEDERAL_URBAN_GROUP_DESCR", a."PRIMARY_ROUTE_MP", a."ACCIDENT_HOUR",
             a."INJURY_LEVEL", a."INJURY_LEVEL_CODE", a."TRF_CNTRL_DEV_OPRATIONL",
             a."TRF_CNTRL_DEV_OPRATIONL_DESCR", a."ELEMENT_ID_MAPPING", a."OFFSET_MAPPING",
             a."WH_ASSETS_CRASH_ID", a.wh_assets_crash_id AS crash_id,
             a.accident_year AS acct_year, a.no_of_units AS UNIT_COUNT,
             a.no_of_persons AS PERSON_COUNT, a.factored_aadt, a.priority, a.speedsrc,
             a.DRIVER_ACTION1_UNIT1, a.DRIVER_ACTION1_UNIT1_DESCR, a.DRIVER_ACTION2_UNIT1,
             a.DRIVER_ACTION2_UNIT1_DESCR, a.DRIVER_ACTION1_UNIT2,
             a.DRIVER_ACTION1_UNIT2_DESCR, a.DRIVER_ACTION2_UNIT2,
             a.DRIVER_ACTION2_UNIT2_DESCR, STATE_URBAN_RURAL, STATE_URBAN_RURAL_DESCR
        FROM (SELECT b.*,
                     d.element_id    AS element_id_mapping,
                     d.offset        AS offset_mapping,
                     CASE
                         WHEN (UPPER (b.MDOTID) LIKE '%C')
                         THEN
                             SUBSTR (b.MDOTID, 1, 5) || LPAD (SUBSTR (b.MDOTID, 6), 6, '0')
                         ELSE
                             SUBSTR (b.MDOTID, 1, 5) || LPAD (SUBSTR (b.MDOTID, 6), 5, '0')
                     END             AS wh_assets_crash_id,
                     n.factored_aadt,
                     n.priority,
                     'Unknown'       AS speedsrc,
                     n.STATE_URBAN_RURAL,
                     n.STATE_URBAN_RURAL_DESCR
                FROM accidents b
                     JOIN oneelementsetup d ON d.node_id = b.node_id
                     JOIN minelement c ON d.rn = c.min_rn
                     LEFT OUTER JOIN nodes n ON b.node_id = n.node_id
               WHERE b.LOCATION_TYPE = 'NODE'                                   -- node crash
              UNION ALL
              SELECT a.*,
                     a.element_id    AS element_id_mapping,
                     a.offset        AS offset_mapping,
                     CASE
                         WHEN (UPPER (a.MDOTID) LIKE '%C')
                         THEN
                             SUBSTR (a.MDOTID, 1, 5) || LPAD (SUBSTR (a.MDOTID, 6), 6, '0')
                         ELSE
                             SUBSTR (a.MDOTID, 1, 5) || LPAD (SUBSTR (a.MDOTID, 6), 5, '0')
                     END             AS wh_assets_crash_id,
                     s.factored_aadt,
                     s.priority,
                     s.speedsrc,
                     s.STATE_URBAN_RURAL,
                     s.STATE_URBAN_RURAL_DESCR
                FROM accidents a LEFT OUTER JOIN sections s ON a.section_id = s.section_id
               WHERE a.LOCATION_TYPE = 'ELEMENT') a
    ORDER BY accident_date ASC;
