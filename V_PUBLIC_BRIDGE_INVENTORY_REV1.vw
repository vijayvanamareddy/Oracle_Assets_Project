CREATE OR REPLACE VIEW WH_ASSETS.V_PUBLIC_BRIDGE_INVENTORY_REV1
BEQUEATH DEFINER
AS 
SELECT DISTINCT
           i.BRIDGE_NUMBER,
           i.BRIDGE_NAME,
           rs.FACTORED_AADT,
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
           CONCAT (
               CONCAT (
                   CONCAT (CONCAT (i.BRIDGE_NUMBER, '<br>'), i.TOWN_NAME1),
                   '<br>'),
               CASE
                   WHEN NOT i.TOWN_NAME2 IS NULL THEN i.TOWN_NAME2
                   ELSE NULL
               END),
           i.FEATURE_ON_STRUCTURE,
           i.FEATURE_UNDER_STRUCTURE,
           i.LOCATION_DESCRIPTION,
           i.MAINTENANCE_REGION_DESCR,
           i.MINOR_SPAN_CODE_DESCR,
           i.NEIGHBOR_STATE_CODE_DESCR,
           i.PRIMARY_ROUTE_NUMBER,
           i.TOWN_NAME1,
           i.TOWN_NAME2,
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
               WHEN i.MAINTAINER_DESCR =
                    '03 - Town or Township Highway Agency'
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
      FROM ((WH_ASSETS.BRIDGES_ON_ROUTE  br
             INNER JOIN
             WH_ASSETS.ROUTE_SECTIONS    rs
             ON     br.ROUTE_NUMBER = rs.ROUTE_NUMBER
                AND br.SECTION_ID = rs.SECTION_ID)
            INNER JOIN
            WH_ASSETS.HIGHWAY_SECTIONS   hs
            ON rs.SECTION_ID = hs.SECTION_ID)
           LEFT OUTER JOIN WH_ASSETS.IBRIDGES i ON br.BRIDGE_ID = i.BRIDGE_ID
     WHERE     i.ASSET_TYPE = 'Highway Bridge'
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
           AND br.location = 'ON'
    UNION
    SELECT DISTINCT
           i.BRIDGE_NUMBER,
           i.BRIDGE_NAME,
           rs.FACTORED_AADT,
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
           CONCAT (
               CONCAT (
                   CONCAT (CONCAT (i.BRIDGE_NUMBER, '<br>'), i.TOWN_NAME2),
                   '<br>'),
               CASE
                   WHEN NOT i.TOWN_NAME2 IS NULL THEN i.TOWN_NAME1
                   ELSE NULL
               END),
           i.FEATURE_ON_STRUCTURE,
           i.FEATURE_UNDER_STRUCTURE,
           i.LOCATION_DESCRIPTION,
           i.MAINTENANCE_REGION_DESCR,
           i.MINOR_SPAN_CODE_DESCR,
           i.NEIGHBOR_STATE_CODE_DESCR,
           i.PRIMARY_ROUTE_NUMBER,
           i.TOWN_NAME2,  -- Reverse order of town_name1 and town_name2 when town2 is not null
           i.TOWN_NAME1,
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
               WHEN i.MAINTAINER_DESCR =
                    '03 - Town or Township Highway Agency'
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
      FROM ((WH_ASSETS.BRIDGES_ON_ROUTE  br
             INNER JOIN
             WH_ASSETS.ROUTE_SECTIONS    rs
             ON     br.ROUTE_NUMBER = rs.ROUTE_NUMBER
                AND br.SECTION_ID = rs.SECTION_ID)
            INNER JOIN
            WH_ASSETS.HIGHWAY_SECTIONS   hs
            ON rs.SECTION_ID = hs.SECTION_ID)
           LEFT OUTER JOIN WH_ASSETS.IBRIDGES i ON br.BRIDGE_ID = i.BRIDGE_ID
     WHERE     i.ASSET_TYPE = 'Highway Bridge'
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
           AND i.TOWN_NAME2 IS NOT NULL
           AND br.location = 'ON';
