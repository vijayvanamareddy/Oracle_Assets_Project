CREATE OR REPLACE VIEW WH_ASSETS.V_DISSOLVED_ARNOLD
BEQUEATH DEFINER
AS 
WITH
        dis
        AS
            (SELECT c.snapshot_year,
                    c.route_number,
                    begin_mp,
                    end_mp,
                    c.route_name
               FROM v_complete_transp_network c,
                    LATERAL (SELECT t.snapshot_year, t.route_number,
                                    t.begin_section_mp AS begin_mp,
                                    t.end_section_mp AS end_mp, column1 ROUTE_NAME 
                               FROM TABLE (WH_ASSETS.PKG_DISSOLVE.F_DISSOLVE_ROUTE (
                                               'snapshot_year = 2022 AND PRIMARY = ''Y''  
                               AND TRANSPORTATION_MODE = ''HIGHWAY'' AND EXISTING = ''Y''
                        AND row_type = ''Element''',
                                               'ROUTE_NAME')) t
                              WHERE     c.route_number = t.route_number
                                    AND c.snapshot_year = t.snapshot_year
                                    AND c.route_name = t.column1
                                    AND t.begin_section_mp = c.begin_section_mp))
    SELECT '12/31/2022', 
           '23',
           ctn.route_number,
           d.begin_mp,
           d.end_mp,
           d.route_name
      FROM v_complete_transp_network  ctn
           JOIN dis d ON ctn.route_number = d.route_number AND d.end_mp = ctn.end_section_mp
     WHERE ctn.primary = 'Y' AND ctn.snapshot_year = d.snapshot_year;
