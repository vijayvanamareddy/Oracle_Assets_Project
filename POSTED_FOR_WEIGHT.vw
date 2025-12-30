CREATE OR REPLACE VIEW WH_ASSETS.POSTED_FOR_WEIGHT
BEQUEATH DEFINER
AS 
SELECT I.bridge_number,
           bridge_name,
           STRUCTURE_OPEN,
           STRUCTURE_OPEN_DESCR,
           LR_POSTED_DATE,
           posted_weight_tons,
           posted_1_truck,
           posted_4_axle,
           posted_spacing,
           primary_route_number
      FROM ibridges  I
     WHERE structure_open IN ('P', 'R', 'K');
