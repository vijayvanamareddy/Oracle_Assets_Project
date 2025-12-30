CREATE OR REPLACE VIEW WH_ASSETS.V_BRIDGE_PERMIT_POSTED
BEQUEATH DEFINER
AS 
(
    SELECT
      CASE
        WHEN permit.brdgno IS NULL
        THEN posted.bridge_number
        ELSE permit.brdgno
      END bridge_number,
      permit.keyfield,
      permit.mtrns_asset_no_key,
      permit.posted,
      CASE
        WHEN permit.height_source LIKE('%PORTAL%')
        OR posted.posted_source_ext_ol2 LIKE('%PORTAL%')
        THEN 'True'
        ELSE 'False'
      END portal,
      permit.height_source         AS permit_source,
      posted.posted_source_ext_ol2 AS posted_source,
      permit.total_inches          AS permit_total_inches,
      permit.ol_permit_ft          AS permit_feet,
      permit.ol_permit_in          AS permit_inches,
      posted.total_inches          AS posted_total_inches,
      posted.ol_posted_ft          AS posted_feet,
      posted.ol_posted_in          AS posted_inches
    FROM
      v_bns_permit_heights_unpivot permit
    FULL OUTER JOIN v_bns_posted_heights_unpivot posted
    ON
      permit.keyfield = posted.keyfield
  );
