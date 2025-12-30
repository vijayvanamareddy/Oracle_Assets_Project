CREATE OR REPLACE VIEW WH_ASSETS.V_PUBLIC_BRIDGE_INVENTORY
BEQUEATH DEFINER
AS 
WITH
    factored_aadt_alternate_roads
    AS
        (  SELECT bridge_number, SUM (factored_aadt) AS tot_alternate_aadt
             FROM IBRDG_ROADS_ASSOC_HISTORY rd
                  JOIN V_COMPLETE_TRANSP_NETWORK ctn
                      ON rd.section_id = ctn.section_id
            WHERE     rd.STATE = 'CURRENT'
                  AND rd.LOCATION_TYPE = 'A'
                  AND rd.PRIMARY_ROUTE_NUMBER NOT LIKE 'RR%'
                  AND ctn.primary = 'Y'
         GROUP BY bridge_number),
    flattened_towns
    AS
        (SELECT bridge_number, bridge_name, town_name
           FROM ibridges
                UNPIVOT EXCLUDE NULLS (town_name
                                      FOR town
                                      IN (town_name1, town_name2)))
  SELECT DISTINCT
         i.BRIDGE_NUMBER,
         i.BRIDGE_NAME,
         ctn.factored_aadt + NVL (alt.tot_alternate_aadt, 0)
             AS FACTORED_AADT,
         i.CHANNEL_RATING_DESCR,
         i.CULVERT_RATING_DESCR,
         i.DECK_RATING_DESCR,
         i.SUBSTRUCTURE_RATING_DESCR,
         i.SUPERSTRUCTURE_RATING_DESCR,
         i.YEAR_BUILT,
         i.APP_ROAD_ALIGN_RATING_DESCR,
         i.FEDERAL_SUFFICIENCY_RATING,
         i.NBIS_BRIDGE_LENGTH,
         i.LENGTH_MAX_SPAN,
         i.WIDTH_CURB_TO_CURB,
         i.ASSET_STATUS_DESCR,
         i.ASSET_TYPE,
         CASE
             WHEN t.town_name = i.town_name1
             THEN
                 CONCAT (
                     CONCAT (
                         CONCAT (CONCAT (i.BRIDGE_NUMBER, '<br>'),
                                 i.TOWN_NAME1),
                         '<br>'),
                     CASE
                         WHEN NOT i.TOWN_NAME2 IS NULL THEN i.TOWN_NAME2
                         ELSE NULL
                     END)
             WHEN t.town_name = i.town_name2
             THEN
                 CONCAT (
                     CONCAT (
                         CONCAT (CONCAT (i.BRIDGE_NUMBER, '<br>'),
                                 i.TOWN_NAME2),
                         '<br>'),
                     i.town_name1)
         END,
         i.FEATURE_ON_STRUCTURE,
         i.FEATURE_UNDER_STRUCTURE,
         i.LOCATION_DESCRIPTION,
         i.MAINTENANCE_REGION_DESCR,
         i.MINOR_SPAN_CODE_DESCR,
         i.NEIGHBOR_STATE_CODE_DESCR,
         i.PRIMARY_ROUTE_NUMBER,
         CASE
             WHEN t.town_name = i.town_name1 THEN i.TOWN_NAME1
             ELSE i.town_name2
         END,
         CASE
             WHEN t.town_name = i.town_name1 AND i.town_name2 IS NOT NULL
             THEN
                 i.TOWN_NAME2
             WHEN t.town_name = i.town_name2
             THEN
                 i.town_name1
             ELSE
                 NULL
         END,
         i.INSPECTION_DATE,
         i.POSTED_4_AXLE,
         i.POSTED_1_TRUCK,
         i.POSTED_SPACING,
         i.MAIN_SPAN_NUMBER,
         CASE
             WHEN i.MAINTAINER_DESCR = '01 - State Highway Agency'
             THEN
                 'MaineDOT'
             WHEN i.MAINTAINER_DESCR = '02 - County Highway Agency'
             THEN
                 'COUNTY'
             WHEN i.MAINTAINER_DESCR = '03 - Town or Township Highway Agency'
             THEN
                 'Municipality'
             ELSE
                 SUBSTR (i.MAINTAINER_DESCR, 5, 200)
         END,
         CASE
             WHEN i.OWNER_DESCR = '01 - State Highway Agency'
             THEN
                 'MaineDOT'
             WHEN i.OWNER_DESCR = '02 - County Highway Agency'
             THEN
                 'COUNTY'
             WHEN i.OWNER_DESCR = '03 - Town or Township Highway Agency'
             THEN
                 'Municipality'
             ELSE
                 SUBSTR (i.OWNER_DESCR, 5, 200)
         END,
         CASE
             WHEN i.POSTED_WEIGHT_TONS <= 0 THEN NULL
             ELSE i.POSTED_WEIGHT_TONS
         END,
         SUBSTR (i.STRUCTURE_OPEN_DESCR, 4, 200),
         SUBSTR (i.MAIN_SPAN_DESIGN_DESCR, 5, 200),
         SUBSTR (i.MAIN_SPAN_MATERIAL_DESCR, 4, 200)
    FROM WH_ASSETS.IBRIDGES i
         JOIN flattened_towns t ON i.bridge_number = t.bridge_number
         JOIN bridges_on_route br ON i.bridge_id = br.bridge_id
         JOIN V_COMPLETE_TRANSP_NETWORK ctn ON br.section_id = ctn.section_id
         LEFT OUTER JOIN factored_aadt_alternate_roads alt
             ON i.bridge_number = alt.bridge_number
   WHERE     br.primary = 'Y'
         AND br.location = 'ON'
         AND ctn.primary = 'Y'
         AND i.ASSET_TYPE = 'Highway Bridge'
         AND i.ASSET_STATUS_DESCR = 'In-Service'
         AND (   i.TYPE_OF_SERVICE_ON_DESCR IN
                     ('1  - Highway',
                      '4 - Highway-railroad',
                      '5 - Highway-pedestrian',
                      '6 - Overpass structure at an interchange or second level of a multilevel interchange')
              OR i.TYPE_OF_SERVICE_UNDER_DESCR IN
                     ('1 - Highway, with or w/out pedestrian',
                      '4 - Highway - railroad',
                      '6 - Highway - waterway',
                      '8 - Highway - waterway - railroad'))
         AND i.TOWN_NAME1 IS NOT NULL
         AND ctn.route_type IN ('N', 'I')
ORDER BY 1;
