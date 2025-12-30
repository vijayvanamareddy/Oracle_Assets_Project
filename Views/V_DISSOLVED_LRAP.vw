CREATE OR REPLACE VIEW WH_ASSETS.V_DISSOLVED_LRAP
BEQUEATH DEFINER
AS 
WITH
        dis
        AS
            (SELECT c.snapshot_year,
                    c.route_number,
                    begin_mp,
                    end_mp,
                    CASE
                        WHEN begin_mp = c.begin_element_milepoint
                        THEN
                            c.begin_node_id
                        ELSE
                            NULL
                    END    begin_node_id,
                    CASE
                        WHEN begin_mp = c.begin_element_milepoint
                        THEN
                            c.begin_node_description
                        ELSE
                            'Non-node'
                    END    begin_node_description,
                    c.town_name,
                    c.jurisdiction,
                    c.streetname,
                    c.state_urban_rural_descr,
                    c.federal_functional_class,
                    c.maint_resp_winter_descr,
                    c.maint_resp_year_descr,
                    c.wcsh_code,
                    c.plow_crew
               FROM v_complete_transp_network  c,
                    LATERAL (
                        SELECT t.snapshot_year,
                               t.route_number,
                               t.begin_section_mp
                                   AS begin_mp,
                               t.end_section_mp
                                   AS end_mp,
                               column1
                                   townname,
                               column2
                                   jurisdiction,
                               column3
                                   streetname,
                               column4
                                   state_urban_rural_descr,
                               column5
                                   federal_functional_class,
                               column6
                                   maint_resp_winter_descr,
                               column7
                                   maint_resp_year_descr,
                               column8
                                   wcsh_code,
                               column9
                                   plow_crew
                          FROM TABLE (WH_ASSETS.PKG_DISSOLVE.F_DISSOLVE_ROUTE (
                                          'snapshot_year >= 2021 AND PRIMARY = ''Y''  AND RAMP_DESCR NOT IN (''Cut'', ''Ramp'')
                               AND federal_functional_class <> 1 AND TRANSPORTATION_MODE = ''HIGHWAY'' AND EXISTING = ''Y''
                        AND row_type = ''Element''',
                                          'TOWN_NAME',
                                          'JURISDICTION',
                                          'STREETNAME',
                                          'STATE_URBAN_RURAL_DESCR',
                                          'FEDERAL_FUNCTIONAL_CLASS',
                                          'MAINT_RESP_WINTER_DESCR',
                                          'MAINT_RESP_YEAR_DESCR',
                                          'WCSH_CODE',
                                          'PLOW_CREW')) t
                         WHERE     c.route_number = t.route_number
                               AND c.snapshot_year = t.snapshot_year
                               AND c.town_name = t.column1
                               AND c.jurisdiction = t.column2
                               AND c.streetname = t.column3
                               AND t.column4 = c.state_urban_rural_descr
                               AND t.column5 = c.federal_functional_class
                               AND t.column6 = c.maint_resp_winter_descr
                               AND t.column7 = c.maint_resp_year_descr
                               AND t.column8 = c.wcsh_code
                               AND t.column9 = c.plow_crew
                               AND t.begin_section_mp = c.begin_section_mp))
    SELECT ctn.snapshot_year,
           ctn.route_number,
           d.begin_mp,
           d.end_mp,
           d.town_name,
           d.streetname,
           d.begin_node_id,
           d.begin_node_description,
           CASE
               WHEN d.end_mp = ctn.end_element_milepoint THEN ctn.end_node_id
               ELSE NULL
           END    end_node_id,
           CASE
               WHEN d.end_mp = ctn.end_element_milepoint
               THEN
                   ctn.end_node_description
               ELSE
                   'Non-node'
           END    end_node_description,
           d.jurisdiction,
           d.state_urban_rural_descr,
           d.federal_functional_class,
           d.maint_resp_winter_descr,
           d.maint_resp_year_descr,
           ctn.jurisdiction_code,
           d.wcsh_code,
           d.plow_crew,
           ctn.town_code,
           ctn.state_urban_rural,
           ctn.geographic_area_type,
           ctn.county_code,
           ctn.county_name,
           CASE
               WHEN (    ctn.state_urban_rural = '2'
                     AND ctn.JURISDICTION_CODE = 2
                     AND ctn.maint_resp_year_descr <> 'MDOT')
               THEN
                   '2 USA'
               WHEN    (    ctn.state_urban_rural = '2'
                        AND ctn.JURISDICTION_CODE = 1
                        AND ctn.maint_resp_year_descr <> 'MDOT')
                    OR (  ctn.state_urban_rural = '2'
                        AND ctn.JURISDICTION_CODE = 1
                        AND   ctn.maint_resp_year_descr = 'MDOT'
                        AND ctn.plow_crew = 'TOWN')
               THEN
                   '1 USH'
               WHEN     ctn.JURISDICTION_CODE IN (1,
                                                  2,
                                                  3,
                                                  9)
                    AND ctn.WCSH_CODE = 'Y'
               THEN
                   '3 WCSH'
               WHEN ctn.JURISDICTION_CODE = 9 -- AND ctn.state_urban_rural = '1'  
               THEN
                   '6 STW'
               WHEN ctn.JURISDICTION_CODE = 3 -- AND ctn.state_urban_rural = '1' 
               THEN
                   '5 TW'
               WHEN     ctn.state_urban_rural = '1'
                    AND ctn.JURISDICTION_CODE = 2
                    --AND ctn.FEDERAL_FUNCTIONAL_CLASS = 6
               THEN
                   '4 RSA' --Previously named '4 RSAMC' and modified for LRAP updates on 07MAY2025
               ELSE
                   '7 Non-LRAP'
           END    LRAP_Category
      FROM v_complete_transp_network  ctn
           JOIN dis d
               ON     ctn.route_number = d.route_number
                  AND d.end_mp = ctn.end_section_mp
     WHERE ctn.primary = 'Y' AND ctn.snapshot_year = d.snapshot_year;
