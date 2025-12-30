CREATE OR REPLACE VIEW WH_ASSETS.BRIDGE_UNDERCLEARANCE
BEQUEATH DEFINER
AS 
SELECT ol2.bridge_number,
           'MAIN - NORTH OR EAST',
           br.primary_route_number,
           br.primary_route_name,
           br.location_level,
           br.location_type,
           OL2.MTRNS_ASSETNO,
           ol2.OL_NORTH_MAIN_POSTED,
           ol2.OL_NORTH_MAIN_POSTED_FT,
           ol2.OL_NORTH_MAIN_POSTED_IN,
           (ol2.OL_NORTH_MAIN_POSTED_FT) * 12 + (ol2.OL_NORTH_MAIN_POSTED_IN),
           ol2.OL_PERMIT_NORTH_FT,
           ol2.OL_PERMIT_NORTH_IN,
           ((ol2.OL_PERMIT_NORTH_FT * 12) + ol2.OL_PERMIT_NORTH_IN)
      FROM ibridges_history ol2
           LEFT OUTER JOIN IBRDG_ROADS_ASSOC_HISTORY br
               ON     OL2.MTRNS_ASSETNO_N_OR_E = br.MTRNS_ASSETNO
                  and br.state = 'CURRENT' where ol2.state = 'CURRENT'
 and  NOT (    (ol2.OL_PERMIT_NORTH_FT IS NULL)
                AND (ol2.OL_PERMIT_NORTH_IN IS NULL)
                AND (ol2.OL_NORTH_MAIN_POSTED_FT IS NULL)
                AND (ol2.OL_NORTH_MAIN_POSTED_IN IS NULL))
    UNION
    SELECT ol2.bridge_number,
           'MAIN - SOUTH OR WEST',
           br.primary_route_number,
           br.primary_route_name,
           br.location_level,
           br.location_type,
           OL2.MTRNS_ASSETNO,
           ol2.OL_SOUTH_MAIN_POSTED,
           ol2.OL_SOUTH_MAIN_POSTED_FT,
           ol2.OL_SOUTH_MAIN_POSTED_IN,
           (ol2.OL_SOUTH_MAIN_POSTED_FT * 12) + ol2.OL_SOUTH_MAIN_POSTED_IN,
           ol2.OL_PERMIT_SOUTH_FT,
           ol2.OL_PERMIT_SOUTH_IN,
           (ol2.OL_PERMIT_SOUTH_FT * 12) + ol2.OL_PERMIT_SOUTH_IN -- Total Permit Inches,
      FROM  ibridges_history ol2
           LEFT OUTER JOIN IBRDG_ROADS_ASSOC_HISTORY br
               ON     ol2.MTRNS_ASSETNO_S_OR_W = br.MTRNS_ASSETNO
                  AND br.state = 'CURRENT' where ol2.state = 'CURRENT'
     and NOT (    ol2.OL_PERMIT_SOUTH_FT IS NULL
                AND ol2.OL_PERMIT_SOUTH_IN IS NULL
                AND ol2.OL_SOUTH_MAIN_POSTED_FT IS NULL
                AND ol2.OL_SOUTH_MAIN_POSTED_IN IS NULL)
    UNION
    SELECT ol2.bridge_number,
           'RIGHT/NORTH RAMP',
           br.primary_route_number,
           br.primary_route_name,
           br.location_level,
           br.location_type,
           OL2.MTRNS_ASSETNO,
           ol2.OL_NORTH_RAMP_POSTED,
           ol2.OL_NORTH_RAMP_POSTED_FT,
           ol2.OL_NORTH_RAMP_POSTED_IN,
           (ol2.OL_NORTH_RAMP_POSTED_FT) * 12 + ol2.OL_NORTH_RAMP_POSTED_IN,
           ol2.OL_PERMIT_RIGHT_RAMP_FT,
           ol2.OL_PERMIT_RIGHT_RAMP_IN,
           (ol2.OL_PERMIT_RIGHT_RAMP_FT * 12) + ol2.OL_PERMIT_RIGHT_RAMP_IN -- Total Permit Inches,
      FROM ibridges_history ol2       
           LEFT OUTER JOIN IBRDG_ROADS_ASSOC_HISTORY br
               ON     ol2.MTRNS_ASSETNO_RIGHT_RAMP = br.MTRNS_ASSETNO
                  AND br.state = 'CURRENT'
     WHERE  ol2.state = 'CURRENT' AND NOT (    ol2.OL_PERMIT_RIGHT_RAMP_FT IS NULL
                AND ol2.OL_PERMIT_RIGHT_RAMP_IN IS NULL
                AND ol2.OL_NORTH_RAMP_POSTED_FT IS NULL
                AND ol2.OL_NORTH_RAMP_POSTED_IN IS NULL)
    UNION
    SELECT ol2.bridge_number,
           'LEFT/SOUTH RAMP',
           br.primary_route_number,
           br.primary_route_name,
           br.location_level,
           br.location_type,
           OL2.MTRNS_ASSETNO,
           ol2.OL_SOUTH_RAMP_POSTED,
           ol2.OL_SOUTH_RAMP_POSTED_FT,
           ol2.OL_SOUTH_RAMP_POSTED_IN,
           (ol2.OL_SOUTH_RAMP_POSTED_FT * 12) + ol2.OL_SOUTH_RAMP_POSTED_IN,
           ol2.OL_PERMIT_LEFT_RAMP_FT,
           ol2.OL_PERMIT_LEFT_RAMP_IN,
           (ol2.OL_PERMIT_LEFT_RAMP_FT * 12) + ol2.OL_PERMIT_LEFT_RAMP_IN -- Total Permit Inches,
      FROM ibridges_history ol2 
           LEFT OUTER JOIN IBRDG_ROADS_ASSOC_HISTORY br
               ON     ol2.MTRNS_ASSETNO_LEFT_RAMP = br.MTRNS_ASSETNO
                  AND br.state = 'CURRENT'
     WHERE ol2.state = 'CURRENT' AND NOT (    ol2.OL_PERMIT_LEFT_RAMP_FT IS NULL
                AND ol2.OL_PERMIT_LEFT_RAMP_IN IS NULL
                AND ol2.OL_SOUTH_RAMP_POSTED_FT IS NULL
                AND ol2.OL_SOUTH_RAMP_POSTED_IN IS NULL)
    UNION
    SELECT ol2.bridge_number,
           'OTHER',
           br.primary_route_number,
           br.primary_route_name,
           br.location_level,
           br.location_type,
           OL2.MTRNS_ASSETNO,
           ol2.OL_NORTH_OTHER_POSTED,
           ol2.OL_NORTH_OTHER_POSTED_FT,
           ol2.OL_NORTH_OTHER_POSTED_IN,
           (ol2.OL_NORTH_OTHER_POSTED_FT * 12) + ol2.OL_NORTH_OTHER_POSTED_IN,
           ol2.OL_PERMIT_OTHER_FT,
           ol2.OL_PERMIT_OTHER_IN,
           (ol2.OL_PERMIT_OTHER_FT * 12) + ol2.OL_PERMIT_OTHER_IN -- Total Permit Inches,
      FROM ibridges_history ol2 
           LEFT OUTER JOIN IBRDG_ROADS_ASSOC_HISTORY br
               ON     ol2.MTRNS_ASSETNO_OTHER = br.MTRNS_ASSETNO
                  AND br.state = 'CURRENT'
     WHERE ol2.state = 'CURRENT' AND NOT (    ol2.OL_PERMIT_OTHER_FT IS NULL
                AND ol2.OL_PERMIT_OTHER_IN IS NULL
                AND ol2.OL_NORTH_OTHER_POSTED_FT IS NULL
                AND ol2.OL_NORTH_OTHER_POSTED_IN IS NULL)
    UNION
    SELECT br.bridge_number,
           'PORTAL NORTH',
           br.primary_route_number,
           br.primary_route_name,
           2,                                               -- location_level,
           'ON',                                             -- location_type,
           BR.MTRNS_ASSETNO,
           br.OL_PORTAL_NORTH_POSTED,
           br.OL_PORTAL_NORTH_POSTED_FT,
           br.OL_PORTAL_NORTH_POSTED_IN,
           (br.OL_PORTAL_NORTH_POSTED_FT * 12) + br.OL_PORTAL_NORTH_POSTED_IN,
           br.OL_PERMIT_PORTAL_NORTH_FT,
           br.OL_PERMIT_PORTAL_NORTH_IN,
           (br.OL_PERMIT_PORTAL_NORTH_FT * 12) + br.OL_PERMIT_PORTAL_NORTH_IN -- Total Permit Inches
      FROM ibridges_history  br
     WHERE     br.state = 'CURRENT'
           AND NOT (    br.OL_PERMIT_PORTAL_NORTH_FT IS NULL
                    AND br.OL_PERMIT_PORTAL_NORTH_IN IS NULL
                    AND br.OL_PORTAL_NORTH_POSTED_FT IS NULL
                    AND br.OL_PORTAL_NORTH_POSTED_IN IS NULL)
    UNION
    SELECT br.bridge_number,
           'PORTAL SOUTH',
           br.primary_route_number,
           br.primary_route_name,
           2,                                               -- location_level,
           'ON',                                             -- location_type,
           BR.MTRNS_ASSETNO,
           br.OL_PORTAL_SOUTH_POSTED,
           br.OL_PORTAL_SOUTH_POSTED_FT,
           br.OL_PORTAL_SOUTH_POSTED_IN,
           (br.OL_PORTAL_SOUTH_POSTED_FT * 12) + br.ol_portal_south_posted_in,
           br.OL_PERMIT_PORTAL_SOUTH_FT,
           br.OL_PERMIT_PORTAL_SOUTH_IN,
           (br.OL_PERMIT_PORTAL_SOUTH_FT * 12) + br.OL_PERMIT_PORTAL_SOUTH_IN -- Total Permit Inches,
      FROM ibridges_history  br
     WHERE     br.state = 'CURRENT'
           AND NOT (    br.OL_PERMIT_PORTAL_SOUTH_FT IS NULL
                    AND br.OL_PERMIT_PORTAL_SOUTH_IN IS NULL
                    AND br.OL_PORTAL_SOUTH_POSTED_FT IS NULL
                    AND br.OL_PORTAL_SOUTH_POSTED_IN IS NULL);
