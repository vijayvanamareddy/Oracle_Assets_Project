CREATE MATERIALIZED VIEW MV_DISSOLVED_PUBLIC_ROADS
NOCACHE
NOLOGGING
NOCOMPRESS
NOPARALLEL
NO INMEMORY
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
WITH PRIMARY KEY
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
                c.streetname
           FROM v_complete_transp_network  c,
                LATERAL (
                    SELECT t.snapshot_year,
                           t.route_number,
                           t.begin_section_mp     AS begin_mp,
                           t.end_section_mp       AS end_mp,
                           column1                townname,
                           column2                jurisdiction,
                           column3                streetname
                      FROM TABLE (WH_ASSETS.PKG_DISSOLVE.F_DISSOLVE_ROUTE (
                                      'snapshot_year = f_get_snapshot_year AND PRIMARY = ''Y''  AND RAMP_DESCR NOT IN (''Ramp'')
                              AND TRANSPORTATION_MODE = ''HIGHWAY'' AND EXISTING = ''Y''
                        AND row_type = ''Element''',
                                      'TOWN_NAME',
                                      'JURISDICTION',
                                      'STREETNAME')) t
                     WHERE     c.route_number = t.route_number
                           AND c.snapshot_year = t.snapshot_year
                           AND c.town_name = t.column1
                           AND c.jurisdiction = t.column2
                           AND c.streetname = t.column3
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
       CASE
           WHEN d.jurisdiction = 'State hwy' THEN 'State Highway'
           WHEN d.jurisdiction = 'State aid' THEN 'State Aid'
           WHEN d.jurisdiction = 'Townway' THEN 'Town Maintained Year Round'
           WHEN d.jurisdiction = 'Tnwy summer' THEN 'Town Way Summer'
           WHEN d.jurisdiction = 'Tnwy winter' THEN 'Town Way Winter'
           WHEN d.jurisdiction = 'Seas pkwy' THEN 'Seasonal Parkway'
           ELSE 'Other'
       END    AS JURISDICTION,
       ctn.county_name
  FROM v_complete_transp_network  ctn
       JOIN dis d
           ON     ctn.route_number = d.route_number
              AND d.end_mp = ctn.end_section_mp
 WHERE ctn.primary = 'Y' AND ctn.snapshot_year = d.snapshot_year;
