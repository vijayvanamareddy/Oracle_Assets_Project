CREATE OR REPLACE VIEW WH_ASSETS.RTE_TOWN
BEQUEATH DEFINER
AS 
SELECT DISTINCT t2.route_number AS rtcode,
                      t2.route_type AS rttype,
                      t2.route_name AS rtname,
                      t2.route_system AS rtsystem,
                      county_code   AS cntyno,
                      county        AS cntyname,
                      primary       AS primary,
                      towncode      AS towncode,
                      townname      AS townname
        FROM routes t2
             LEFT JOIN wh_common.dim_towns t1 ON t1.townname = t2.town
             LEFT JOIN wh_common.dim_routes t3
                 ON t3.route_number = t2.route_number
       WHERE county_code IS NOT NULL
    ORDER BY t2.route_number;
