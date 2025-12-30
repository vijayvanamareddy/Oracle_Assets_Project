CREATE OR REPLACE VIEW WH_ASSETS.V_BNS_PERMIT_HEIGHTS_UNPIVOT
BEQUEATH DEFINER
AS 
WITH
        overlimitbridges
        AS
            (SELECT brdgno,
                    total_inches,
                    height_source,
                    brdgno || '//' || height_source AS keyfield,
                    ol_permit_ft,
                    ol_permit_in,
                    extra_characters_inch,
                    extra_characters_ft,
                    mtrns_asset_no,
                    metrans_asset,
                    mtrns_asset_no_key,
                    POSTED
               FROM ((SELECT brdgno,
                             REGEXP_SUBSTR (MTRNS_ASSET_NO,
                                            '[^-]+',
                                            1,
                                            1)
                                 AS MTRNS_ASSET_NO,
                             REGEXP_SUBSTR (MTRNS_ASSET_NO,
                                            '[^-]+',
                                            1,
                                            2)
                                 AS METRANS_ASSET,
                             MTRNS_ASSET_NO
                                 AS MTRNS_ASSET_NO_KEY,
                             CASE
                                 WHEN     ol_permit_ft IS NOT NULL
                                      AND ol_permit_in IS NOT NULL
                                 THEN
                                     (OL_PERMIT_FT * 12) + OL_PERMIT_IN
                                 WHEN     ol_Permit_ft IS NOT NULL
                                      AND ol_permit_in IS NULL
                                 THEN
                                     ol_permit_ft * 12
                                 WHEN     ol_permit_ft IS NULL
                                      AND ol_Permit_in IS NOT NULL
                                      AND ol_permit_in > 0
                                 THEN
                                     ol_permit_in
                                 ELSE
                                     NULL
                             END
                                 AS TOTAL_INCHES,
                             OL_PERMIT_FT,
                             OL_PERMIT_IN,
                             HEIGHT_SOURCE,
                             extra_characters_inch,
                             extra_characters_ft,
                             POSTED
                        FROM (SELECT bridge_number
                                         AS BRDGNO,
                                     CASE
                                         WHEN REGEXP_LIKE (
                                                  OL_permit_FT,
                                                  '^-?[[:digit:],.]*$')
                                         THEN
                                             CAST (OL_Permit_FT AS NUMBER)
                                         ELSE
                                             NULL
                                     END
                                         AS OL_permit_FT,
                                     CASE
                                         WHEN REGEXP_LIKE (
                                                  OL_Permit_IN,
                                                  '^-?[[:digit:],.]*$')
                                         THEN
                                             CAST (OL_Permit_IN AS NUMBER)
                                         ELSE
                                             NULL
                                     END
                                         AS OL_Permit_IN,
                                     height_source,
                                     CAST (MTRNS_ASSET_NO AS VARCHAR (15))
                                         AS MTRNS_ASSET_NO,
                                     extra_characters_inch,
                                     extra_characters_ft,
                                     POSTED
                                FROM (SELECT bridge_number,
                                             TRIM (
                                                 REGEXP_REPLACE (
                                                     ol_permit_ft,
                                                     '\s',
                                                     ' '))
                                                 AS ol_permit_ft,
                                             TRIM (
                                                 REGEXP_REPLACE (
                                                     ol_permit_in,
                                                     '\s',
                                                     ' '))
                                                 AS ol_permit_in,
                                             CASE
                                                 WHEN TRIM (
                                                          REGEXP_REPLACE (
                                                              ol_permit_in,
                                                              '\s',
                                                              ' ')) !=
                                                      ol_permit_in
                                                 THEN
                                                     'Y'
                                                 ELSE
                                                     NULL
                                             END
                                                 AS extra_characters_inch,
                                             CASE
                                                 WHEN TRIM (
                                                          REGEXP_REPLACE (
                                                              ol_permit_ft,
                                                              '\s',
                                                              ' ')) !=
                                                      ol_permit_ft
                                                 THEN
                                                     'Y'
                                                 ELSE
                                                     NULL
                                             END
                                                 AS extra_characters_ft,
                                             height_source,
                                             mtrns_asset_no,
                                             POSTED
                                        FROM (SELECT *
                                                FROM ext_ol
                                                     UNPIVOT INCLUDE NULLS ((OL_permit_FT,
                                                                             ol_permit_IN,
                                                                             MTRNS_ASSET_NO,
                                                                             POSTED)
                                                                           FOR (
                                                                               height_source)
                                                                           IN ((OL_PERMIT_SOUTH_FT,
                                                                                OL_PERMIT_SOUTH_IN,
                                                                                MTRNS_ASSETNO_S_OR_W,
                                                                                OL_SOUTH_MAIN_POSTED) AS ('SOUTH_WEST_UNDER'),
                                                                              (OL_PERMIT_NORTH_FT,
                                                                               OL_PERMIT_NORTH_IN,
                                                                               MTRNS_ASSETNO_N_OR_E,
                                                                               OL_NORTH_MAIN_POSTED) AS ('NORTH_EAST_UNDER'),
                                                                              (OL_PERMIT_PORTAL_SOUTH_FT,
                                                                               OL_PERMIT_PORTAL_SOUTH_IN,
                                                                               MTRNS_ASSETNO_PORTAL_S_OR_W,
                                                                               OL_PORTAL_SOUTH_POSTED) AS ('SOUTH_WEST_PORTAL_OVER'),
                                                                              (OL_PERMIT_PORTAL_NORTH_FT,
                                                                               OL_PERMIT_PORTAL_NORTH_in,
                                                                               MTRNS_ASSETNO_PORTAL_N_OR_E,
                                                                               OL_PORTAL_NORTH_POSTED) AS ('NORTH_EAST_PORTAL_OVER'),
                                                                              (OL_PERMIT_LEFT_RAMP_FT,
                                                                               OL_PERMIT_LEFT_RAMP_IN,
                                                                               MTRNS_ASSETNO_LEFT_RAMP,
                                                                               OL_SOUTH_RAMP_POSTED) AS ('LEFT_RAMP_UNDER'),
                                                                              (OL_PERMIT_RIGHT_RAMP_FT,
                                                                               OL_PERMIT_RIGHT_RAMP_IN,
                                                                               MTRNS_ASSETNO_RIGHT_RAMP,
                                                                               OL_NORTH_RAMP_POSTED) AS ('RIGHT_RAMP_UNDER'),
                                                                              (OL_PERMIT_OTHER_ft,
                                                                               OL_PERMIT_OTHER_in,
                                                                               MTRNS_ASSETNO_OTHER,
                                                                               OL_NORTH_OTHER_POSTED) AS ('OTHER_UNDER')))))))))
      SELECT "BRDGNO",
             "TOTAL_INCHES",
             "HEIGHT_SOURCE",
             "KEYFIELD",
             "OL_PERMIT_FT",
             "OL_PERMIT_IN",
             "EXTRA_CHARACTERS_INCH",
             "EXTRA_CHARACTERS_FT",
             "MTRNS_ASSET_NO",
             "METRANS_ASSET",
             "MTRNS_ASSET_NO_KEY",
             POSTED
        FROM overlimitbridges
       WHERE total_inches IS NOT NULL OR POSTED IS NOT NULL
    ORDER BY brdgno;
