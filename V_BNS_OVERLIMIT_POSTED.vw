CREATE OR REPLACE VIEW WH_ASSETS.V_BNS_OVERLIMIT_POSTED
BEQUEATH DEFINER
AS 
WITH
        overlimitbridges
        AS
            (SELECT brdgno,
                    total_inches,
                    height_source,
                    keyfield, MTRNS_ASSET_NO,
    METRANS_ASSET,
    MTRNS_ASSET_NO_KEY,
    POSTED
               FROM v_bns_permit_heights_unpivot)
      SELECT a."BRIDGE_NUMBER",
             a."OL_POSTED_FT",
             a."OL_POSTED_IN",
             a."TOTAL_INCHES",
             POSTED,
             a."POSTED_SOURCE_EXT_OL2",
             a."MEASURE_SOURCE_EXT_OL",
             a."KEYFIELD",
             b.height_source,
             b.total_inches AS measured_inches,
             extra_characters_inch,
             extra_characters_ft,
              MTRNS_ASSET_NO,
    METRANS_ASSET,
    MTRNS_ASSET_NO_KEY
        FROM v_bns_posted_heights_unpivot a
             LEFT OUTER JOIN overlimitbridges b ON a.keyfield = b.keyfield
       WHERE OL_POSTED_FT IS NOT NULL
    ORDER BY bridge_number;
