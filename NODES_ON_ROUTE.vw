CREATE OR REPLACE VIEW WH_ASSETS.NODES_ON_ROUTE
BEQUEATH DEFINER
AS 
SELECT r.route_number,
           r.BEGIN_ELEMENT_MILEPOINT,
           r.END_ELEMENT_MILEPOINT,
           r.route_type,
           r.primary,
           n.primary_route_num,
           r.element_id,
           r.element_wid,
           r.section_id,
           r.town,
           n.node_id,
           n.node_description,
           n.no_of_legs,
           CASE
               WHEN n.NODE_ID = r.begin_node_id AND r.direction = 1
               THEN
                   0
               WHEN n.NODE_ID = r.begin_node_id AND r.direction = -1
               THEN
                   r.element_length
               WHEN n.NODE_ID = r.end_node_id AND r.direction = 1
               THEN
                   r.element_length
               WHEN n.NODE_ID = r.end_node_id AND r.direction = -1
               THEN
                   0
           END
               offset,
           CASE
               WHEN n.NODE_ID = r.begin_node_id
               THEN
                   r.BEGIN_element_milepoint
               WHEN n.NODE_ID = r.end_node_id
               THEN
                   r.end_element_milepoint
           END
               Milepoint,
           CASE
               WHEN n.NODE_ID = r.begin_node_id THEN 'BEGIN'
               WHEN n.NODE_ID = r.end_node_id THEN 'END'
           END
               node_position
      FROM nodes  n
           LEFT OUTER JOIN route_sections r
               ON    (    (n.node_id = r.begin_node_id)
                      AND (   (r.begin_offset = 0 AND r.direction = 1)
                           OR (    r.end_offset = r.element_length
                               AND r.direction = -1)))
                  OR (    (n.node_id = r.end_node_id)
                      AND (   (    r.end_offset = r.element_length
                               AND r.direction = 1)
                           OR (r.begin_offset = 0 AND r.direction = -1)));
