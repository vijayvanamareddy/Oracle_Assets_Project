CREATE MATERIALIZED VIEW MV_BRIDGE_UNDERCLEARANCE_QA
NOCACHE
LOGGING
NOCOMPRESS
NOPARALLEL
NO INMEMORY
BUILD IMMEDIATE
REFRESH FORCE ON DEMAND
WITH PRIMARY KEY
AS 
(
    SELECT
      c.bridge_number AS bridge_number,
      bridge_name     AS bridge_name,
      pointer_group,
      owner,
      owner_descr,
      min_vert_under_ref_feature_descr,
      location_type,
      mtrns_asset_key_source,
      mtrns_asset_source,
      keyfield,
      mtrns_asset_no_key,
      posted,
      permit_source,
      posted_source,
      portal,
      CASE
        WHEN posted_total_inches IS NOT NULL
        THEN posted_total_inches
        WHEN posted_total_inches IS NULL
        AND permit_total_inches  IS NOT NULL
        THEN permit_total_inches
        WHEN posted_total_inches IS NULL
        AND permit_total_inches  IS NULL
        THEN vun_sign_posting_in_nbi54b
      END clearance_height_inches,
      CASE
        WHEN posted_total_inches IS NOT NULL
        THEN floor(posted_total_inches / 12)
          || ' FT '
          || mod(posted_total_inches,12)
          || ' IN'
        WHEN posted_total_inches IS NULL
        AND permit_total_inches  IS NOT NULL
        THEN floor(permit_total_inches / 12)
          || ' FT '
          || mod(permit_total_inches,12)
          || ' IN'
        WHEN posted_total_inches       IS NULL
        AND permit_total_inches        IS NULL
        AND vun_sign_posting_in_nbi54b IS NOT NULL
        THEN floor(vun_sign_posting_in_nbi54b / 12)
          || ' FT '
          || mod(vun_sign_posting_in_nbi54b,12)
          || ' IN'
      END clearance_height_sign,
      CASE
        WHEN posted_total_inches IS NOT NULL
        THEN 'Posting'
        WHEN posted_total_inches IS NULL
        AND permit_total_inches  IS NOT NULL
        AND pointer_group        <> 'U - NO AW POINTER'
        THEN 'Permit'
        WHEN posted_total_inches       IS NULL
        AND permit_total_inches        IS NULL
        AND vun_sign_posting_in_nbi54b IS NOT NULL
        THEN 'NBI54B'
        WHEN pointer_group              = 'U - NO AW POINTER'
        AND vun_sign_posting_in_nbi54b IS NOT NULL
        THEN 'NBI54B'
        WHEN posted_total_inches       IS NULL
        AND permit_total_inches        IS NULL
        AND vun_sign_posting_in_nbi54b IS NULL
        THEN 'No Source'
      END clearance_height_source,
      CASE
        WHEN TRIM(posted) = 'True'
        THEN 'Posted'
        WHEN
          (
            posted NOT LIKE('%True%')
          OR posted IS NULL
          )
        AND posted_total_inches <= 174
        THEN 'Should be Posted - Posted'
        WHEN
          (
            posted NOT LIKE('%True%')
          OR posted IS NULL
          )
        AND permit_total_inches <= 174
        THEN 'Should be Posted - Permit'
      END posting_status,
      permit_total_inches,
      permit_feet,
      permit_inches,
      posted_total_inches,
      posted_feet,
      posted_inches,
      vun_sign_posting_in_nbi54b AS nbi54b_sign_inches,
      vun_sign_posting_nbi54b    AS nbi54b_sign
    FROM
      (
        SELECT
          a.*,
          b.KEYFIELD,
          b.MTRNS_ASSET_NO_KEY,
          b.POSTED,
          b.PORTAL,
          b.PERMIT_SOURCE,
          b.POSTED_SOURCE,
          b.PERMIT_TOTAL_INCHES,
          b.PERMIT_FEET,
          b.PERMIT_INCHES,
          b.POSTED_TOTAL_INCHES,
          b.POSTED_FEET,
          b.POSTED_INCHES,
          'AW POINTER ADDED' AS pointer_group
        FROM
          v_bridge_pointers a
        INNER JOIN v_bridge_permit_posted b
        ON
          a.mtrns_asset_key_source = b.mtrns_asset_no_key
        UNION ALL
        SELECT
          a.*,
          b.KEYFIELD,
          b.MTRNS_ASSET_NO_KEY,
          b.POSTED,
          b.PORTAL,
          b.PERMIT_SOURCE,
          b.POSTED_SOURCE,
          b.PERMIT_TOTAL_INCHES,
          b.PERMIT_FEET,
          b.PERMIT_INCHES,
          b.POSTED_TOTAL_INCHES,
          b.POSTED_FEET,
          b.POSTED_INCHES,
          'PORTAL POINTER DERIVED' AS pointer_group
        FROM
          (
            SELECT
              *
            FROM
              v_bridge_pointers
            WHERE
              mtrns_asset_source = 'BRDG'
          )
          a
        INNER JOIN
          (
            SELECT
              *
            FROM
              v_bridge_permit_posted
            WHERE
              mtrns_asset_no_key IS NULL
            AND portal            = 'True'
          )
          b
        ON
          a.bridge_number = b.bridge_number
        UNION ALL
        SELECT
          a.*,
          NULL                AS KEYFIELD,
          NULL                AS MTRNS_ASSET_NO_KEY,
          NULL                AS POSTED,
          NULL                AS PORTAL,
          NULL                AS PERMIT_SOURCE,
          NULL                AS POSTED_SOURCE,
          NULL                AS PERMIT_TOTAL_INCHES,
          NULL                AS PERMIT_FEET,
          NULL                AS PERMIT_INCHES,
          NULL                AS POSTED_TOTAL_INCHES,
          NULL                AS POSTED_FEET,
          NULL                AS POSTED_INCHES,
          'U - NO AW POINTER' AS pointer_group
        FROM
          (
            SELECT
              *
            FROM
              v_bridge_pointers
            WHERE
              location_type                 = 'U'
            AND mtrns_asset_key_source NOT IN
              (
                SELECT DISTINCT
                  (mtrns_asset_no_key)
                FROM
                  v_bridge_permit_posted
                WHERE
                  mtrns_asset_no_key IS NOT NULL
              )
          )
          a
      )
      c
    LEFT OUTER JOIN
      (
        SELECT
          bridge_number,
          vun_sign_posting_in_nbi54b,
          vun_sign_posting_nbi54b
        FROM
          v_bns_bridge_nbi_height_calcs
        WHERE
          vun_sign_posting_nbi54b IS NOT NULL
      )
      d
    ON
      c.bridge_number = d.bridge_number
  );
