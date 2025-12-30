CREATE OR REPLACE VIEW WH_ASSETS.V_BNS_BRIDGE
BEQUEATH DEFINER
AS 
WITH
        bridgespatial
        AS
            (SELECT a.BRDGNO,
                    a.GPS_EASTING,
                    a.GPS_NORTHING,
                    0
                        AS OFF_SYSTEM,
                    aa.ne_id_of
                        AS LINK_ID,
                    aa.nm_begin_mp
                        AS OFFSET,
                    CAST (
                        'INSPTCH AND BRIDGE ONSYSTEM(V_NM_NIT_BRDG_SDO_DT)' AS VARCHAR (50))
                        AS SOURCE,
                    aa.status
                        AS brdg_status_code,
                    e.ial_meaning
                        AS brdg_status_desc
               FROM IBRIDGES  b
                    JOIN V_bns_bridge@METRANS a ON a.brdgno = b.BRidge_NUMBER
                    LEFT OUTER JOIN V_NM_BRDG_NW@METRANS aa
                        ON aa.V_NM_BRDG_NW = b.BRidge_NUMBER
                    LEFT OUTER JOIN NM_INV_ATTRI_LOOKUP_ALL@METRANS e
                        ON     aa.status = ial_value
                           AND IAL_DOMAIN = 'BRDG_STATUS'
             UNION ALL
             SELECT c.BRIDGE_ID
                        AS BRDGNO,
                    c.GPS_EASTING
                        AS GPS_EASTING,
                    c.GPS_NORTHING
                        AS GPS_NORTHING,
                    1
                        AS OFF_SYSTEM,
                    NULL
                        AS LINK_ID,
                    NULL
                        AS OFFSET,
                    CAST (
                        'INSPTCH AND BRIDGE OFFSYSTEM(v_nm_bros)' AS VARCHAR (50))
                        AS SOURCE,
                    c.status
                        AS brdg_status_code,
                    e.ial_meaning
                        AS brdg_status_desc
               FROM IBRIDGES  d
                    JOIN v_nm_bros@METRANS c ON c.bridge_id = d.BRidge_NUMBER
                    LEFT OUTER JOIN NM_INV_ATTRI_LOOKUP_ALL@METRANS e
                        ON     c.status = ial_value
                           AND IAL_DOMAIN = 'BRDG_STATUS'
             UNION ALL
             SELECT a.BRDGNO,
                    a.GPS_EASTING,
                    a.GPS_NORTHING,
                    NULL
                        AS OFF_SYSTEM,
                    NULL
                        AS LINK_ID,
                    NULL
                        AS OFFSET,
                    CAST (
                        'METRANS ON SYSTEM BUT NOT INSPTCH' AS VARCHAR (50))
                        AS SOURCE,
                    aa.status
                        AS brdg_status_code,
                    e.ial_meaning
                        AS brdg_status_desc
               FROM V_bns_bridge@METRANS  a
                    LEFT OUTER JOIN V_NM_BRDG_NW@METRANS aa
                        ON aa.V_NM_BRDG_NW = a.BRdgno
                    LEFT OUTER JOIN NM_INV_ATTRI_LOOKUP_ALL@METRANS e
                        ON     aa.status = ial_value
                           AND IAL_DOMAIN = 'BRDG_STATUS'
              WHERE a.brdgno NOT IN (SELECT bridge_number FROM ibridges)
             UNION ALL
             SELECT a.BRIDGE_ID
                        AS BRDGNO,
                    a.GPS_EASTING
                        AS GPS_EASTING,
                    a.GPS_NORTHING
                        AS GPS_NORTHING,
                    NULL
                        AS OFF_SYSTEM,
                    NULL
                        AS LINK_ID,
                    NULL
                        AS OFFSET,
                    CAST (
                        'METRANS OFF SYSTEM BUT NOT IN INSPTCH' AS VARCHAR (50))
                        AS SOURCE,
                    a.status
                        AS brdg_status_code,
                    e.ial_meaning
                        AS brdg_status_desc
               FROM v_nm_bros@METRANS  a
                    LEFT OUTER JOIN NM_INV_ATTRI_LOOKUP_ALL@METRANS e
                        ON     a.status = ial_value
                           AND IAL_DOMAIN = 'BRDG_STATUS'
                    LEFT OUTER JOIN WH_COMMON.DIM_BRIDGES f
                        ON a.bridge_id = f.bridge
              WHERE a.BRIDGE_ID NOT IN (SELECT bridge_number FROM Ibridges)),
              archivedbridgedomain as (SELECT *
    FROM (SELECT bridge_number,
                 CASE
                     WHEN    REGEXP_LIKE (
                                 archived_reason,
                                 '^((.*? )?(not|meet|definition|requirements|structure|bridge|qualify|criteria|field|verified)([ ,.!?]|$)){4}.*$',
                                 'i')
                          OR REGEXP_LIKE (
                                 archived_reason,
                                 '^((.*? )?(size|not|qualify|bridge)([ ,.!?]|$)){4}.*$',
                                 'i')
                          OR REGEXP_LIKE (
                                 archived_reason,
                                 '^((.*? )?(not|bridge)([ ,.!?]|$)){2}.*$',
                                 'i')
                     THEN
                         'Not a Bridge'
                     WHEN    REGEXP_LIKE (
                                 archived_reason,
                                 '^((.*? )?(road|no|not|public|way|maintained|town maintains|yearround)([ ,.!?]|$)){3}.*$',
                                 'i')
                          OR REGEXP_LIKE (
                                 archived_reason,
                                 '^((.*? )?(town maintains|yearround)([ ,.!?]|$)){2}.*$',
                                 'i')
                     THEN
                         'Not Public Way'
                     WHEN    REGEXP_LIKE (
                                 archived_reason,
                                 '^((.*? )?(removed|removal)([ ,.!?]|$)){}.*$',
                                 'i')
                          OR REGEXP_LIKE (
                                 archived_reason,
                                 '^((.*? )?(structure|bridge|will be|removed|by the town|facility|carried|carries|no longer)([ ,.!?]|$)){3}.*$',
                                 'i')
                          OR REGEXP_LIKE (
                                 archived_reason,
                                 '^((.*? )?(scheduled|removal|bridge)([ ,.!?]|$)){3}.*$',
                                 'i')
                     THEN
                         'Removed or Scheduled to be Removed'
                     WHEN REGEXP_LIKE (
                              archived_reason,
                              '^((.*? )?(structural|deficiencies)([ ,.!?]|$)){2}.*$',
                              'i')
                     THEN
                         'Structural Deficiencies'
                     WHEN REGEXP_LIKE (
                              archived_reason,
                              '^((.*? )?(asset|bridge|archived)([ ,.!?]|$)){2}.*$',
                              'i')
                     THEN
                         'Bridge Archived'
                     WHEN REGEXP_LIKE (
                              archived_reason,
                              '^((.*? )?(private|privately|owned|road|bridge)([ ,.!?]|$)){2}.*$',
                              'i')
                     THEN
                         'Private Road'
                     ELSE
                         'Other'
                 END
                     AS archived_domain,
                 archived_reason
            FROM archived_bridges
           WHERE archived_reason IS NOT NULL)
--where archived_domain is  null
ORDER BY archived_domain ASC)
      SELECT a."BRDGNO",
             a."GPS_EASTING",
             a."GPS_NORTHING",
             a."OFF_SYSTEM",
             a."LINK_ID",
             a."OFFSET",
             a."SOURCE",
             a."BRDG_STATUS_CODE",
             a."BRDG_STATUS_DESC",
             COALESCE (b.BRIDGE_NAME, c.Bridge_name, d.Bridge_name)
                 AS BRDG_NAME,
             COALESCE (b.feature_on_structure,
                       c.feature_on_structure,
                       d.feature_on_structure)
                 AS facility,
             COALESCE (b.feature_under_structure,
                       c.feature_under_structure,
                       d.feature_under_structure)
                 AS featint,
             COALESCE (b.year_built, c.year_built, d.year_built)
                 AS YEARBUILT,
             COALESCE (b.year_reconstructed,
                       c.year_reconstructed,
                       d.year_reconstructed)
                 AS YEARRECON,
             COALESCE (b.length_max_span, c.length_max_span, d.length_max_span)
                 AS MAXSPAN,
             COALESCE (b.DECK_AREA, c.DECK_AREA, d.DECK_AREA)
                 AS deck_area,
             COALESCE (b.width, c.width, d.width)
                 AS DECKWIDTH,
             COALESCE (b.BRIDGE_LENGTH, c.BRIDGE_LENGTH, d.BRIDGE_LENGTH)
                 AS bridge_length,
             COALESCE (b.inventory_rating,
                       c.inventory_rating,
                       d.inventory_rating)
                 AS irload,
             COALESCE (b.operating_rating,
                       c.operating_rating,
                       d.operating_rating)
                 AS orload,
             NULL
                 AS STRTNAME,
             COALESCE (b.inspection_date, c.inspection_date, d.inspection_date)
                 AS inspdate,
             COALESCE (b.federal_sufficiency_rating,
                       c.federal_sufficiency_rating,
                       d.federal_sufficiency_rating)
                 AS SUFF_RATE,
             COALESCE (b.main_span_design,
                       c.main_span_design,
                       d.main_span_design)
                 AS DESIGNMAIN,
             COALESCE (b.main_span_design_descr,
                       c.main_span_design_descr,
                       d.main_span_design_descr)
                 AS DESIGNMAIN_DESC,
             COALESCE (b.main_span_material,
                       c.main_span_material,
                       d.main_span_material)
                 AS MATERIALMAIN,
             COALESCE (b.main_span_material_descr,
                       c.main_span_material_descr,
                       d.main_span_material_descr)
                 AS MATERIALMAIN_DESC,
             COALESCE (b.deck_rating, c.deck_rating, d.deck_rating)
                 AS DKRATING,
             COALESCE (b.deck_rating_descr,
                       c.deck_rating_descr,
                       d.deck_rating_descr)
                 AS DKRATING_DESC,
             COALESCE (b.superstructure_rating,
                       c.superstructure_rating,
                       d.superstructure_rating)
                 AS SUPRATING,
             COALESCE (b.superstructure_rating_descr,
                       c.superstructure_rating_descr,
                       d.superstructure_rating_descr)
                 AS SUPRATING_DESC,
             COALESCE (b.substructure_rating,
                       c.substructure_rating,
                       d.substructure_rating)
                 AS SUBRATING,
             COALESCE (b.substructure_rating_descr,
                       c.substructure_rating_descr,
                       d.substructure_rating_descr)
                 AS SUBRATING_DESC,
             COALESCE (b.culvert_rating, c.culvert_rating, d.culvert_rating)
                 AS CULVRATING,
             COALESCE (b.culvert_rating_descr,
                       c.culvert_rating_descr,
                       d.culvert_rating_descr)
                 AS CULVRATING_DESC,
             COALESCE (b.channel_rating, c.channel_rating, d.channel_rating)
                 AS CHANRATING,
             COALESCE (b.channel_rating_descr,
                       c.channel_rating_descr,
                       d.channel_rating_descr)
                 AS CHANRATING_DESC,
             COALESCE (b.scour_rating, c.scour_rating, d.scour_rating)
                 AS SCOURCRIT,
             COALESCE (b.scour_rating_descr,
                       c.scour_rating_descr,
                       d.scour_rating_descr)
                 AS SCOURCRIT_DESC,
             COALESCE (b.owner, c.owner, d.owner)
                 AS OWNER,
             COALESCE (b.owner_descr,
                       c.owner_descr,
                       d.owner_descr)
                 AS OWNER_DESC,
             CAST (NULL AS NUMBER (9))
                 AS ADTTOTAL,
             CAST (NULL AS NUMBER (9, 3))
                 AS TRUCKPCT,
             COALESCE (b.detour_length, c.detour_length, d.detour_length)
                 AS BYPASSLEN,
             CAST (NULL AS NUMBER (9, 2))
                 AS roadwidth,
             CAST (NULL AS NUMBER (1))
                 AS ON_UNDER,
                 case when c.archived_reason is not null then c.archived_reason
                 else null
                 end as archived_reason  ,
                 case when c.archived_date  is not null then c.archived_date
                 else null
                 end as archived_date  ,
                 case when e.archived_domain is not null then e.archived_domain
                 else null
                 end    as archived_domain
        FROM bridgespatial a
             LEFT OUTER JOIN ibridges b ON a.brdgno = b.BRidge_NUMBER
             LEFT OUTER JOIN archived_bridges c ON a.brdgno = c.bridge_number
             LEFT OUTER JOIN proposed_bridges d ON a.brdgno = d.bridge_number
              LEFT OUTER JOIN archivedbridgedomain e ON a.brdgno = e.bridge_number
    ORDER BY a.brdgno ASC;
