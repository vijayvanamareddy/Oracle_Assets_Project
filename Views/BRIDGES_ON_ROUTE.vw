CREATE OR REPLACE VIEW WH_ASSETS.BRIDGES_ON_ROUTE
BEQUEATH DEFINER
AS 
SELECT DISTINCT
           b.bridge_id,
           b.bridge_number,
           r.route_number,
           r.primary,
           b.primary_route_number,
           r.element_id,
           b.highway_id_on_structure,
           b.section_id,
           'ON'
               Location,
           OFFSET,
           CASE
               WHEN direction = 1
               THEN
                   ROUND (begin_element_milepoint + OFFSET, 2)
               WHEN direction = -1
               THEN
                   ROUND (end_element_milepoint - OFFSET, 2)
           END
               "Milepoint"
      FROM route_sections r, ibridges b
     WHERE     r.section_id = b.section_id
           AND b.type_of_service_on IN ('1', -- originally highway only
                                        '2', -- added rail 2-4-20
                                        '4',
                                        '5',
                                        '6')                        
    UNION
    SELECT DISTINCT
           b.bridge_id,
           b.bridge_number,
           r.route_number,
           r.primary,
           b.primary_route_number,
           r.element_id,
           b.highway_id,
           b.section_id,
           b.location_type,
           OFFSET,
           CASE
               WHEN direction = 1
               THEN
                   ROUND (begin_element_milepoint + offset, 2)
               WHEN direction = -1
               THEN
                   ROUND (end_element_milepoint - offset, 2)
           END
               "Milepoint"
      FROM route_sections r, IBRDG_ROADS_ASSOC_HISTORY b
     WHERE r.section_id = b.section_id AND b.end_date IS NULL
    ORDER BY route_number;
