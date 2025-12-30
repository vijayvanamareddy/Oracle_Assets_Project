CREATE OR REPLACE VIEW WH_ASSETS.V_BNS_BRIDGE_ATTRIBUTES
BEQUEATH DEFINER
AS 
WITH
        bridge_conversions
        AS
            (SELECT bridge_number,
                    SUBSTR (owner, 2, 1)          AS owner_number,
                    SUBSTR (maintainer, 2, 1)     AS maintainer_number,
                    LPAD (county, 3, '0')         AS county_padded
               FROM (SELECT bridge_number,
                            owner,
                            maintainer,
                            county
                       FROM ibridges
                     UNION
                     SELECT bridge_number,
                            owner,
                            maintainer,
                            county
                       FROM proposed_bridges
                     UNION
                     SELECT bridge_number,
                            owner,
                            maintainer,
                            county
                       FROM archived_bridges)),
        UNDERCLEARANCEBRIDGES
        AS
            (  SELECT bridge_number, posted_list
                 FROM (  SELECT BRIDGE_NUMBER,
                                LISTAGG (posted, '|')
                                    WITHIN GROUP (ORDER BY bridge_number, posted)    AS posted_list
                           FROM (SELECT BRIDGE_NUMBER,
                                        CASE
                                            WHEN posted IS NULL THEN 'False'
                                            ELSE posted
                                        END    AS posted --CASE WHEN upper(posted)='FALSE' THEN NULL ELSE POSTED END AS POSTED
                                   FROM BRIDGE_UNDERCLEARANCE --where bridge_number = '5814'
                                                             )
                       GROUP BY BRIDGE_NUMBER
                       ORDER BY bridge_number)
                WHERE posted_list LIKE '%|%'
             GROUP BY bridge_number, posted_list),
        allbridges
        AS
            (SELECT b.BRIDGE_number,
                    b.BRIDGE_NAME,
                    b.towncode,
                    b.town_name1,
                    B.TOWNCODE2,
                    b.town_name2,
                    GEOGRAPHIC_REGION,
                    GEOGRAPHIC_REGION_DESCR,
                    b.owner,
                    b.owner_descr,
                    b.userbrdg_owner,
                    b.userbrdg_owner_descr,
                    b.MAINTAINER,
                    b.maintainer_descr,
                    b.userbrdg_maintainer,
                    b.userbrdg_maintainer_descr,
                    posted_bridge_indicator_descr,
                    posted_bridge_indicator,
                    post_type,
                    post_type_descr,
                    county_name,
                    county2_name,
                    feature_on_structure,
                    feature_under_structure,
                    vehicle_load_limit,
                    truck_weight_post_limit,
                    operating_rating,
                    inventory_rating,
                    width,
                    bridge_length,
                    type_of_service_on,
                    type_of_service_on_descr,
                    type_of_service_under,
                    type_of_service_under_descr,
                    VEHICLE_HEIGHT_OVER,
                    VEHICLE_HEIGHT_UNDER,
                    NAVIGATION_HORIZONTAL,
                    NAVIGATION_VERTICAL,
                    min_vert_under_clearance,
                    MIN_VERTICAL_CLEARANCE_ON,
                    NEIGHBOR_STATE_CODE,
                    BRIDGE_INDICATOR,
                    length_max_span,
                    INVRTE_FUNCTIONCLASS,
                    INVRTE_FUNCTIONCLASS_DESCR,
                    INVRTE_ON_NHS,
                    INVRTE_ON_NHS_DESCR,
                    INVRTE_LRS_RTENUM,
                    PRIMARY_ROUTE_NUMBER,
                    PRIORITY,
                    LATITUDE,
                    LONGITUDE,
                    POSTED_WEIGHT_TONS,
                    posted_spacing,
                    posted_1_truck,
                    posted_4_axle,
                    NULL     AS LR_POSTED_DATE,
                    STRUCTURE_OPEN,
                    STRUCTURE_OPEN_DESCR,
                    posted
               FROM proposed_bridges b
             UNION
             SELECT b.BRIDGE_number,
                    b.BRIDGE_NAME,
                    b.towncode,
                    b.town_name1,
                    B.TOWNCODE2,
                    b.town_name2,
                    GEOGRAPHIC_REGION,
                    GEOGRAPHIC_REGION_DESCR,
                    b.owner,
                    b.owner_descr,
                    b.userbrdg_owner,
                    b.userbrdg_owner_descr,
                    b.MAINTAINER,
                    b.maintainer_descr,
                    b.userbrdg_maintainer,
                    b.userbrdg_maintainer_descr,
                    posted_bridge_indicator_descr,
                    posted_bridge_indicator,
                    post_type,
                    post_type_descr,
                    county_name,
                    county2_name,
                    feature_on_structure,
                    feature_under_structure,
                    vehicle_load_limit,
                    truck_weight_post_limit,
                    operating_rating,
                    inventory_rating,
                    width,
                    bridge_length,
                    type_of_service_on,
                    type_of_service_on_descr,
                    type_of_service_under,
                    type_of_service_under_descr,
                    VEHICLE_HEIGHT_OVER,
                    VEHICLE_HEIGHT_UNDER,
                    NAVIGATION_HORIZONTAL,
                    NAVIGATION_VERTICAL,
                    min_vert_under_clearance,
                    MIN_VERTICAL_CLEARANCE_ON,
                    NEIGHBOR_STATE_CODE,
                    BRIDGE_INDICATOR,
                    length_max_span,
                    INVRTE_FUNCTIONCLASS,
                    INVRTE_FUNCTIONCLASS_DESCR,
                    INVRTE_ON_NHS,
                    INVRTE_ON_NHS_DESCR,
                    INVRTE_LRS_RTENUM,
                    PRIMARY_ROUTE_NUMBER,
                    PRIORITY,
                    LATITUDE,
                    LONGITUDE,
                    POSTED_WEIGHT_TONS,
                    posted_spacing,
                    posted_1_truck,
                    posted_4_axle,
                    LR_POSTED_DATE,
                    STRUCTURE_OPEN,
                    STRUCTURE_OPEN_DESCR,
                    posted
               FROM ibridges b
             UNION
             SELECT b.BRIDGE_number,
                    b.BRIDGE_NAME,
                    b.towncode,
                    b.town_name1,
                    B.TOWNCODE2,
                    b.town_name2,
                    GEOGRAPHIC_REGION,
                    GEOGRAPHIC_REGION_DESCR,
                    b.owner,
                    b.owner_descr,
                    b.userbrdg_owner,
                    b.userbrdg_owner_descr,
                    b.MAINTAINER,
                    b.maintainer_descr,
                    b.userbrdg_maintainer,
                    b.userbrdg_maintainer_descr,
                    posted_bridge_indicator_descr,
                    posted_bridge_indicator,
                    post_type,
                    post_type_descr,
                    county_name,
                    county2_name,
                    feature_on_structure,
                    feature_under_structure,
                    vehicle_load_limit,
                    truck_weight_post_limit,
                    operating_rating,
                    inventory_rating,
                    width,
                    bridge_length,
                    type_of_service_on,
                    type_of_service_on_descr,
                    type_of_service_under,
                    type_of_service_under_descr,
                    VEHICLE_HEIGHT_OVER,
                    VEHICLE_HEIGHT_UNDER,
                    NAVIGATION_HORIZONTAL,
                    NAVIGATION_VERTICAL,
                    min_vert_under_clearance,
                    MIN_VERTICAL_CLEARANCE_ON,
                    NEIGHBOR_STATE_CODE,
                    BRIDGE_INDICATOR,
                    length_max_span,
                    INVRTE_FUNCTIONCLASS,
                    INVRTE_FUNCTIONCLASS_DESCR,
                    INVRTE_ON_NHS,
                    INVRTE_ON_NHS_DESCR,
                    INVRTE_LRS_RTENUM,
                    PRIMARY_ROUTE_NUMBER,
                    PRIORITY,
                    LATITUDE,
                    LONGITUDE,
                    POSTED_WEIGHT_TONS,
                    posted_spacing,
                    posted_1_truck,
                    posted_4_axle,
                    NULL     AS LR_POSTED_DATE,
                    STRUCTURE_OPEN,
                    STRUCTURE_OPEN_DESCR,
                    posted
               FROM archived_bridges b),
        newbridgepostingtypeandstatus
        AS
            (SELECT bridge_number, post_type_descr_new, post_status_new
               FROM (  SELECT A.BRIDGE_NUMBER,
                              CASE 
WHEN 
((posted_weight_tons IS NOT NULL and posted_weight_tons>0 ) OR STRUCTURE_OPEN IN ('R', 'P')) and b.bridge_number is null THEN  '1 Weight Limit'
WHEN POSTED_WEIGHT_TONS IS NOT NULL OR (STRUCTURE_OPEN IN ('R', 'P') OR upper(posted) in ('TRUE', 'YES') ) AND B.BRIDGE_NUMBER IS NOT NULL THEN '5 Weight '||CHR(38)||' Underclearanc'
WHEN upper(posted_4_axle) = 'YES' OR  posted_spacing= 'YES' THEN  '9 Other - lane closure e'  
WHEN POSTED_1_TRUCK = 'YES' AND B.BRIDGE_NUMBER IS NOT NULL THEN '6 One Truck '||CHR(38)||' Underclear'         
WHEN upper(posted_1_truck) = 'YES' THEN '2 One truck at a time li'    
    WHEN B.BRIDGE_NUMBER IS NOT NULL THEN '3 Underclearance Limit'
    ELSE '0 None needed'
    END AS POST_TYPE_DESCR_NEW ,
                              CASE
                                  WHEN STRUCTURE_OPEN = 'A'
                                  THEN
                                      '1 Open'
                                  WHEN structure_open = 'K'
                                  THEN
                                      '2 Closed'
                                  WHEN    structure_open IN ('R', 'P')
                                       OR UPPER (posted) IN ('TRUE', 'YES')
                                  THEN
                                      '3 Posted'
                                  WHEN STRUCTURE_OPEN = 'D'
                                  THEN
                                      '5 Temp. Shoring (no weig'
                                  WHEN STRUCTURE_OPEN = 'E'
                                  THEN
                                      '4 Temp. Structure (no re'
                                  ELSE
                                      '1 Open'
                              END
                                  AS POST_STATUS_NEW,
                              posted,
                              STRUCTURE_OPEN,
                              STRUCTURE_OPEN_DESCR,
                              LR_POSTED_DATE,
                              posted_weight_tons,
                              posted_1_truck,
                              posted_4_axle,
                              posted_spacing,
                              CASE
                                  WHEN REGEXP_LIKE (posted_bridge_indicator,
                                                    '^-?[[:digit:],.]*$')
                                  THEN
                                      CAST (posted_bridge_indicator AS NUMBER)
                                  ELSE
                                      NULL
                              END
                                  AS post_status,
                              posted_bridge_indicator_descr
                                  AS post_desc,
                              TRIM (SUBSTR (posted_bridge_indicator_descr, 2))
                                  AS D_POST_STA,
                              CASE
                                  WHEN REGEXP_LIKE (post_type,
                                                    '^-?[[:digit:],.]*$')
                                  THEN
                                      CAST (post_type AS NUMBER)
                                  ELSE
                                      NULL
                              END
                                  AS post_type,
                              post_type_descr
                                  AS type_desc,
                              TRIM (SUBSTR (post_type_descr, 2))
                                  AS D_POST_TYP,
                              post_type
                                  AS post_type_original,
                              post_type_descr
                                  AS post_type_descr_original,
                              posted_bridge_indicator,
                              posted_bridge_indicator_descr
                         FROM allbridges A
                              LEFT OUTER JOIN UNDERCLEARANCEBRIDGES B
                                  ON A.BRIDGE_NUMBER = B.BRIDGE_NUMBER --where POSTED  IN ('Yes', 'True')
                     ORDER BY structure_open) a)
    SELECT b.BRIDGE_number
               AS BRIDGE_NUM,
           b.BRIDGE_NAME
               AS BRDG_NAME,
           b.towncode || ' ' || town_name1
               AS town1,
           b.towncode
               AS TOWN1_GEOCODE,
           b.town_name1
               AS TOWN1_NAME,
           CASE
               WHEN b.towncode2 = '999' THEN ''
               ELSE b.towncode2 || ' ' || town_name2
           END
               AS town2,
           B.TOWNCODE2
               AS TOWN2_GEOCODE,
           CASE WHEN b.town_name2 = '' THEN 'No Town 2' ELSE b.town_name2 END
               AS TOWN2_NAME,
           TRIM (LEADING 0 FROM GEOGRAPHIC_REGION)
               AS WH_REGION_CODE,
           TRIM (REGEXP_SUBSTR (GEOGRAPHIC_REGION_DESCR,
                                '(.*?)([[:space:]]-[[:space:]]|$)',
                                1,
                                2))
               AS WH_REGION_NAME,
           GEOGRAPHIC_REGION_DESCR,
           b.owner
               AS owner,
           /*CASE
              when b.owner_descr ='03 - Town or Township Highway Agency'  then 'Town/Township Hwy Agency'
              when b.owner_descr = '26 - Private (other than railroad)' then '26 Private(nonRailroad)'
              WHEN b.owner_descr IS NOT NULL
              THEN
                 TRIM (REGEXP_SUBSTR (b.owner_descr,
                                      '[^-]+',
                                      1,
                                      2))
              ELSE
                 NULL
           END
              AS owner_desc,*/
           b.owner_descr
               AS owner_desc,
           b.userbrdg_owner
               AS owner_tide,
           b.userbrdg_owner_descr
               AS owner_desc_tide,
           b.MAINTAINER
               AS CUSTODIAN,
           /*CASE
              when b.maintainer_descr ='03 - Town or Township Highway Agency'  then 'Town/Township Hwy Agency'
              when b.maintainer_descr = '26 - Private (other than railroad)' then '26 Private(nonRailroad)'
              WHEN b.maintainer_descr IS NOT NULL
              THEN
                 TRIM (REGEXP_SUBSTR (b.maintainer_descr,
                                      '[^-]+',
                                      1,
                                      2))
              ELSE
                 NULL
           END
              AS cust_desc,*/
           b.maintainer_descr
               AS cust_desc,
           b.userbrdg_maintainer
               AS custodian_tide,
           b.userbrdg_maintainer_descr
               AS custodian_desc_tide,
           CASE
               WHEN REGEXP_LIKE (post_status_new, '^-?[[:digit:]]{1}')
               THEN
                   CAST (SUBSTR (post_status_new, 1, 1) AS NUMBER)
               ELSE
                   NULL
           END
               AS post_status,
           CASE
               WHEN REGEXP_LIKE (posted_bridge_indicator,
                                 '^-?[[:digit:],.]*$')
               THEN
                   CAST (posted_bridge_indicator AS NUMBER)
               ELSE
                   NULL
           END
               AS post_status_old,
           post_status_new
               AS post_desc,
           posted_bridge_indicator_descr
               AS post_desc_old,
           TRIM (SUBSTR (post_status_new, 2))
               AS D_POST_STA,
           TRIM (SUBSTR (posted_bridge_indicator_descr, 2))
               AS D_POST_STA_old,
           CASE
               WHEN REGEXP_LIKE (post_type_descr_new, '^-?[[:digit:]]{1}')
               THEN
                   CAST (SUBSTR (post_type_descr_new, 1, 1) AS NUMBER)
               ELSE
                   NULL
           END
               AS post_type,
           CASE
               WHEN REGEXP_LIKE (post_type, '^-?[[:digit:],.]*$')
               THEN
                   CAST (post_type AS NUMBER)
               ELSE
                   NULL
           END
               AS post_type_old,
           post_type_descr_new
               AS type_desc,
           post_type_descr
               AS type_desc_old,
           TRIM (SUBSTR (post_type_descr_new, 2))
               AS D_POST_TYP,
           TRIM (SUBSTR (post_type_descr, 2))
               AS D_POST_TYP_old,
           lu3.description
               AS county_desc,
           county_name,
           county2_name,
           lu4.description
               AS county2_desc,
           feature_on_structure
               AS facility,
           feature_under_structure
               AS featint,
           ROUND (NVL (POSTED_WEIGHT_TONS, 0) * .90718472, 5)
               AS vh_mton,
           ROUND (NVL (POSTED_WEIGHT_TONS, 0) * .90718472, 5)
               AS tk_mton,
           NVL (posted_weight_tons, 0)
               vh_ton,
           NVL (posted_weight_tons, 0)
               tk_ton,
           --ROUND (operating_rating * .90718472, 3) AS or_mton,
           --ROUND (inventory_rating * .90718472, 3) AS ir_mton,
           operating_rating
               AS or_ton,
           inventory_rating
               AS ir_ton,
           width
               AS deck_width,
           bridge_length,
           CASE
               WHEN REGEXP_LIKE (type_of_service_on, '^-?[[:digit:],.]*$')
               THEN
                   CAST (type_of_service_on AS NUMBER)
               ELSE
                   NULL
           END
               AS SERVICE_TYPE_ON,
           type_of_service_on_descr
               AS service_type_on_desc,
           CASE
               WHEN REGEXP_LIKE (type_of_service_under, '^-?[[:digit:],.]*$')
               THEN
                   CAST (type_of_service_under AS NUMBER)
               ELSE
                   NULL
           END
               AS SERVICE_TYPE_UNDER,
           type_of_service_under_descr
               AS service_type_under_desc,
           CASE
               WHEN ROUND (VEHICLE_HEIGHT_OVER, 1) >= 99.9
               THEN
                   VEHICLE_HEIGHT_OVER
               WHEN VEHICLE_HEIGHT_OVER = -1
               THEN
                   99.9
               WHEN VEHICLE_HEIGHT_OVER = 0
               THEN
                   99.9
               ELSE
                   VEHICLE_HEIGHT_OVER
           END
               AS VEHICLE_HEIGHT_OVER,
           CASE
               WHEN ROUND (VEHICLE_HEIGHT_OVER, 1) >= 99.9
               THEN
                   VEHICLE_HEIGHT_OVER
               WHEN VEHICLE_HEIGHT_OVER = -1
               THEN
                   99.9
               WHEN VEHICLE_HEIGHT_OVER = 0
               THEN
                   99.9
               ELSE
                   ((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12
           END
               AS VEHICLE_HEIGHT_OVER_INCHES,
           CASE
               WHEN ROUND (VEHICLE_HEIGHT_OVER, 1) >= 99.9
               THEN
                   ''
               WHEN VEHICLE_HEIGHT_OVER = -1
               THEN
                   ''
               WHEN VEHICLE_HEIGHT_OVER = 0
               THEN
                   ''
               WHEN ROUND (MOD (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12, 12)) =
                    0
               THEN
                      CAST (
                          FLOOR (
                              (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12) / 12)
                              AS VARCHAR (3))
                   || ' FT '
               ELSE
                      CAST (
                          FLOOR (
                              (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12) / 12)
                              AS VARCHAR (3))
                   || ' FT '
                   || CAST (
                          ROUND (
                              MOD (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12,
                                   12))
                              AS VARCHAR (3))
                   || ' IN'
           END
               AS VEH_OVER_SIGN_POSTING,
           CASE
               WHEN ROUND (VEHICLE_HEIGHT_OVER, 1) >= 99.9
               THEN
                   VEHICLE_HEIGHT_OVER
               WHEN VEHICLE_HEIGHT_OVER = -1
               THEN
                   99.9
               WHEN VEHICLE_HEIGHT_OVER = 0
               THEN
                   99.9
               WHEN ROUND (MOD (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12, 12)) =
                    0
               THEN
                   FLOOR (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12)
               ELSE
                     (  (FLOOR (
                             (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12) / 12))
                      * 12)
                   + ROUND (
                         MOD (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12, 12))
           END
               AS VEH_OVER_SIGN_POSTING_IN,
           VEHICLE_HEIGHT_OVER * .3048
               AS VEHICLE_HEIGHT_OVER_METERS,
           CASE
               WHEN ROUND (VEHICLE_HEIGHT_UNDER, 1) >= 99.9
               THEN
                   VEHICLE_HEIGHT_UNDER
               WHEN VEHICLE_HEIGHT_UNDER = -1
               THEN
                   99.9
               ELSE
                   VEHICLE_HEIGHT_UNDER
           END
               AS VEHICLE_HEIGHT_UNDER,
           CASE
               WHEN ROUND (VEHICLE_HEIGHT_UNDER, 1) >= 99.9
               THEN
                   VEHICLE_HEIGHT_UNDER
               WHEN VEHICLE_HEIGHT_UNDER = -1
               THEN
                   99.9
               WHEN VEHICLE_HEIGHT_UNDER = 0
               THEN
                   99.9
               ELSE
                   ((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12
           END
               AS VEHICLE_HEIGHT_UNDER_INCHES,
           CASE
               WHEN ROUND (VEHICLE_HEIGHT_UNDER, 1) >= 99.9
               THEN
                   ''
               WHEN VEHICLE_HEIGHT_UNDER = -1
               THEN
                   ''
               WHEN VEHICLE_HEIGHT_UNDER = 0
               THEN
                   ''
               WHEN ROUND (
                        MOD (((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12, 12)) =
                    0
               THEN
                      CAST (
                          FLOOR (
                              (((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12) / 12)
                              AS VARCHAR (3))
                   || ' FT '
               ELSE
                      CAST (
                          FLOOR (
                              (((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12) / 12)
                              AS VARCHAR (3))
                   || ' FT '
                   || CAST (
                          ROUND (
                              MOD (((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12,
                                   12))
                              AS VARCHAR (3))
                   || ' IN'
           END
               AS VEH_UNDER_SIGN_POSTING,
           CASE
               WHEN ROUND (VEHICLE_HEIGHT_UNDER, 1) >= 99.9
               THEN
                   VEHICLE_HEIGHT_UNDER
               WHEN VEHICLE_HEIGHT_UNDER = -1
               THEN
                   99.9
               WHEN VEHICLE_HEIGHT_UNDER = 0
               THEN
                   99.9
               WHEN ROUND (
                        MOD ((((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12), 12)) =
                    0
               THEN
                   FLOOR (((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12)
               ELSE
                     (  (FLOOR (
                             (((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12) / 12))
                      * 12)
                   + ROUND (
                         MOD (((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12, 12))
           END
               AS VEH_UNDER_SIGN_POSTING_IN,
           VEHICLE_HEIGHT_UNDER * .3048
               AS VEHICLE_HEIGHT_UNDER_METERS,
           NAVIGATION_HORIZONTAL,
           NAVIGATION_HORIZONTAL * .3048
               AS NAVIGATION_HORIZONTAL_METERS,
           NAVIGATION_VERTICAL,
           NAVIGATION_VERTICAL * .3048
               AS NAVIGATION_VERTICAL_METERS,
           CASE
               WHEN ROUND (MIN_VERT_UNDER_CLEARANCE, 1) >= 99.9
               THEN
                   MIN_VERT_UNDER_CLEARANCE
               ELSE
                   MIN_VERT_UNDER_CLEARANCE
           END
               AS MIN_VERT_UNDER_CLERANCE,
           min_vert_under_clearance * .3048
               AS MIN_VERT_UNDER_METERS,
           MIN_VERTICAL_CLEARANCE_ON,
           MIN_VERTICAL_CLEARANCE_ON * .3048
               AS MIN_VERT_OVER_METERS,
           CASE
               WHEN NEIGHBOR_STATE_CODE IN ('231', '331', 'CAN')
               THEN
                   NEIGHBOR_STATE_CODE
               ELSE
                   NULL
           END
               AS NEIGHBOR_STATE_CODE_NEW,
           CASE
               WHEN NEIGHBOR_STATE_CODE IN ('231', '331', 'CAN')
               THEN
                   SUBSTR (NEIGHBOR_STATE_CODE, 2, 2)
               ELSE
                   NULL
           END
               AS NEIGHBOR_STATE_CODE,
           BRIDGE_INDICATOR
               AS USERKEY1,
           length_max_span
               AS MAXSPAN,
           INVRTE_FUNCTIONCLASS,
           INVRTE_FUNCTIONCLASS_DESCR,
           INVRTE_ON_NHS,
           INVRTE_ON_NHS_DESCR,
           INVRTE_LRS_RTENUM,
           PRIMARY_ROUTE_NUMBER
               AS WH_PRIMARY_ROUTE_NUMBER,
           PRIORITY
               AS WH_PRIORITY,
           CASE
               WHEN REGEXP_LIKE (LATITUDE, '([\d.]+)')
               THEN
                   CAST (LATITUDE AS NUMBER (9, 6))
               ELSE
                   NULL
           END
               AS BRIDGE_SYSTEM_LATITUDE,
           CASE
               WHEN     SUBSTR (longitude, 1, 2) <> '--'
                    AND REGEXP_LIKE (LONGITUDE, '([\d.]+)')
               THEN
                   CAST (LONGITUDE AS NUMBER (9, 6))
               WHEN SUBSTR (longitude, 1, 2) = '--'
               THEN
                   CAST (SUBSTR (longitude, 2) AS NUMBER (9, 6))
               ELSE
                   NULL
           END
               AS BRIDGE_SYSTEM_LONGITUDE
      FROM allbridges  b
           LEFT OUTER JOIN bridge_conversions bc
               ON b.bridge_number = bc.bridge_number
           LEFT OUTER JOIN newbridgepostingtypeandstatus d
               ON b.bridge_number = d.bridge_number
           LEFT OUTER JOIN ext_bridge_lookups lu3
               ON lu3.code = bc.county_padded AND lu3.FIELD_ID = '2000300'
           LEFT OUTER JOIN ext_bridge_lookups lu4
               ON lu4.code = bc.county_padded AND lu4.FIELD_ID = '2000300'
     WHERE LENGTH (b.bridge_number) <= 4;
