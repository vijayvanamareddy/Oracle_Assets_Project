CREATE OR REPLACE VIEW WH_ASSETS.V_BNS_POSTED_HEIGHTS_UNPIVOT
BEQUEATH DEFINER
AS 
SELECT a."BRIDGE_NUMBER",
             a."OL_POSTED_FT",
             a."OL_POSTED_IN",
             a."TOTAL_INCHES",
             a."POSTED_SOURCE_EXT_OL2",
             a."MEASURE_SOURCE_EXT_OL",
             a."KEYFIELD",            
             extra_characters_inch,
             extra_characters_ft
        FROM (SELECT bridge_number,
                     ol_posted_ft,
                     ol_posted_in,
                     CASE
                         WHEN     ol_posted_ft IS NOT NULL
                              AND ol_posted_in IS NOT NULL
                         THEN
                             (OL_posted_FT * 12) + OL_posted_IN
                         WHEN ol_posted_ft IS NOT NULL AND ol_posted_in IS NULL
                         THEN
                             ol_posted_ft * 12
                         WHEN     ol_posted_ft IS NULL
                              AND ol_posted_in IS NOT NULL
                              AND ol_posted_in > 0
                         THEN
                             ol_posted_in
                         ELSE
                             NULL
                     END
                         AS TOTAL_INCHES,
                     posted_source_ext_ol2,
                     measure_source_ext_ol,
                     bridge_number || '//' || measure_source_ext_ol
                         AS keyfield,
                     extra_characters_inch,
                     extra_characters_ft
                FROM (SELECT *
                        FROM (SELECT bridge_number,
                                     CASE
                                         WHEN REGEXP_LIKE (
                                                  OL_POSTED_FT,
                                                  '^-?[[:digit:],.]*$')
                                         THEN
                                             CAST (OL_POSTED_FT AS NUMBER)
                                         ELSE
                                             NULL
                                     END
                                         AS OL_POSTED_FT,
                                     CASE
                                         WHEN REGEXP_LIKE (
                                                  OL_POSTED_IN,
                                                  '^-?[[:digit:],.]*$')
                                         THEN
                                             CAST (OL_POSTED_IN AS NUMBER)
                                         ELSE
                                             NULL
                                     END
                                         AS OL_POSTED_IN,
                                     posted_source_ext_ol2,
                                     measure_source_ext_ol,
                                     extra_characters_inch,
                                     extra_characters_ft
                                FROM (SELECT bridge_number,
                                             TRIM (
                                                 REGEXP_REPLACE (ol_posted_ft,
                                                                 '\s',
                                                                 ' '))
                                                 AS ol_posted_ft,
                                             TRIM (
                                                 REGEXP_REPLACE (ol_posted_in,
                                                                 '\s',
                                                                 ' '))
                                                 AS ol_posted_in,
                                             CASE
                                                 WHEN TRIM (
                                                          REGEXP_REPLACE (
                                                              ol_posted_in,
                                                              '\s',
                                                              ' ')) !=
                                                      ol_posted_in
                                                 THEN
                                                     'Y'
                                                 ELSE
                                                     NULL
                                             END
                                                 AS extra_characters_inch,
                                             CASE
                                                 WHEN TRIM (
                                                          REGEXP_REPLACE (
                                                              ol_posted_ft,
                                                              '\s',
                                                              ' ')) !=
                                                      ol_posted_ft
                                                 THEN
                                                     'Y'
                                                 ELSE
                                                     NULL
                                             END
                                                 AS extra_characters_ft,
                                             posted_source_ext_ol2,
                                             measure_source_ext_ol
                                        FROM (SELECT *
                                                FROM ext_ol2
                                                     UNPIVOT INCLUDE NULLS ((OL_Posted_FT,
                                                                             ol_posted_IN)
                                                                           FOR (
                                                                               posted_source_ext_ol2,
                                                                               measure_source_ext_ol)
                                                                           IN ((OL_north_main_posted_FT,
                                                                                OL_north_main_posted_in) AS ('NORTH_MAIN',
                                                                                                             'NORTH_EAST_UNDER'),
                                                                              (OL_NORTH_OTHER_POSTED_FT,
                                                                               OL_NORTH_OTHER_POSTED_IN) AS ('NORTH_OTHER',
                                                                                                             'OTHER_UNDER'),
                                                                              (OL_NORTH_RAMP_POSTED_FT,
                                                                               OL_NORTH_RAMP_POSTED_IN) AS ('NORTH_RAMP',
                                                                                                            'RIGHT_RAMP_UNDER'),
                                                                              (OL_SOUTH_MAIN_POSTED_FT,
                                                                               OL_SOUTH_MAIN_POSTED_IN) AS ('SOUTH_MAIN',
                                                                                                            'SOUTH_WEST_UNDER'),
                                                                              (OL_SOUTH_OTHER_POSTED_FT,
                                                                               OL_SOUTH_OTHER_POSTED_IN) AS ('SOUTH_OTHER',
                                                                                                             'OTHER_UNDER'),
                                                                              (OL_SOUTH_RAMP_POSTED_FT,
                                                                               OL_SOUTH_RAMP_POSTED_IN) AS ('SOUTH_RAMP',
                                                                                                            'LEFT_RAMP_UNDER'),
                                                                              (OL_PORTAL_NORTH_POSTED_FT,
                                                                               OL_PORTAL_NORTH_POSTED_IN) AS ('PORTAL_NORTH',
                                                                                                              'NORTH_EAST_PORTAL_OVER'),
                                                                              (OL_PORTAL_SOUTH_POSTED_FT,
                                                                               OL_PORTAL_SOUTH_POSTED_IN) AS ('PORTAL_SOUTH',
                                                                                                              'SOUTH_WEST_PORTAL_OVER'))))))
                       WHERE OL_POSTED_FT IS NOT NULL)) a;
