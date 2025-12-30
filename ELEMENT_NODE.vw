CREATE OR REPLACE VIEW WH_ASSETS.ELEMENT_NODE
BEQUEATH DEFINER
AS 
select distinct element_id, begin_node_id from elements
union
      select distinct element_id, end_node_id from elements;
