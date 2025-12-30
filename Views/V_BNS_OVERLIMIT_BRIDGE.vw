CREATE OR REPLACE VIEW WH_ASSETS.V_BNS_OVERLIMIT_BRIDGE
BEQUEATH DEFINER
AS 
WITH
        overlimitbridgesetup
        AS
            (SELECT brdgno,
                    METRANS_ASSET,
                    MTRNS_ASSET_NO,
                    MTRNS_ASSET_NO_KEY,
                    TOTAL_INCHES,
                    OL_PERMIT_FT,
                    OL_PERMIT_IN,
                    HEIGHT_SOURCE,
                    extra_characters_inch,
                    extra_characters_ft,
                    posted,
                    keyfield
               FROM v_bns_permit_heights_unpivot)
      SELECT a."BRDGNO",
             a."MTRNS_ASSET_NO",
             a."METRANS_ASSET",
             a.MTRNS_ASSET_NO_KEY,
             a."VEH_SIGN_POSTING_IN",
             a."OL_PERMIT_FT",
             a."OL_PERMIT_IN",
             a."HEIGHT_SOURCE",
             a."VEH_SIGN_POSTING",
             a."NE_ID_OF",
             a."NM_BEGIN_MP",
             b.bridge_name,
             c.SERVICE_TYPE_ON,
             c.service_type_on_desc,
             c.SERVICE_TYPE_UNDER,
             c.service_type_under_desc,
             c.vun_nbi_54b,              --use the BRIDGE_FIELDMAPPINGS object
             c.VUN_INCHES_nbi_54b,
             c.VUN_SIGN_POSTING_nbi54b,
             c.VUN_SIGN_POSTING_IN_nbi54b,
             c.vov_nbi_53,
             c.VOV_INCHES_nbi_53,
             c.VOV_SIGN_POSTING_nbi_53,
             c.VOV_SIGN_POSTING_IN_nbi_53,
             extra_characters_inch,
             extra_characters_ft,
             a.posted,
             a.keyfield
        FROM (SELECT brdgno,
                     mtrns_asset_no,
                     metrans_asset,
                     MTRNS_ASSET_NO_KEY,
                     total_inches
                         AS VEH_SIGN_POSTING_IN,
                     ol_permit_ft,
                     ol_permit_in,
                     height_source,
                     CASE
                         WHEN     ol_permit_ft IS NOT NULL
                              AND (    ol_permit_in IS NOT NULL
                                   AND ol_permit_in > 0)
                         THEN
                             ol_permit_ft || ' FT ' || ol_permit_in || ' IN'
                         WHEN     ol_permit_ft IS NOT NULL
                              AND (ol_permit_in IS NULL OR ol_permit_in = 0)
                         THEN
                             ol_permit_ft || ' FT '
                         ELSE
                             NULL
                     END
                         AS VEH_SIGN_POSTING,
                     b.ne_id_of,
                     nm_begin_mp,
                     extra_characters_inch,
                     extra_characters_ft,
                     a.posted,
                     a.keyfield
                FROM overlimitbridgesetup a
                     JOIN v_nm_brpt_nw@metrans b
                         ON a.mtrns_asset_no = b.iit_ne_id
               WHERE metrans_asset = 'BRPT'
              UNION ALL
              SELECT brdgno,
                     mtrns_asset_no,
                     metrans_asset,
                     MTRNS_ASSET_NO_KEY,
                     total_inches
                         AS VEH_SIGN_POSTING_IN,
                     ol_permit_ft,
                     ol_permit_in,
                     height_source,
                     CASE
                         WHEN     ol_permit_ft IS NOT NULL
                              AND (    ol_permit_in IS NOT NULL
                                   AND ol_permit_in > 0)
                         THEN
                             ol_permit_ft || ' FT ' || ol_permit_in || ' IN'
                         WHEN     ol_permit_ft IS NOT NULL
                              AND (ol_permit_in IS NULL OR ol_permit_in = 0)
                         THEN
                             ol_permit_ft || ' FT '
                         ELSE
                             NULL
                     END
                         AS VEH_SIGN_POSTING,
                     b.ne_id_of,
                     nm_begin_mp,
                     extra_characters_inch,
                     extra_characters_ft,
                     a.posted,
                     a.keyfield
                FROM overlimitbridgesetup a
                     JOIN v_nm_brdg_nw@metrans b
                         ON a.mtrns_asset_no = b.iit_ne_id
               WHERE metrans_asset = 'BRDG') a
             JOIN ibridges b ON a.brdgno = b.bridge_number
             JOIN v_bns_bridge_nbi_height_calcs c ON a.brdgno = c.bridge_number
       WHERE LENGTH (b.bridge_number) <= 4
    ORDER BY BRDGNO, HEIGHT_SOURCE;
