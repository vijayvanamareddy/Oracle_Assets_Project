CREATE OR REPLACE VIEW WH_ASSETS.V_BRIDGE_POINTERS
BEQUEATH DEFINER
AS 
(
    SELECT
      a.bridge_number,
      bridge_name,
      owner,
      owner_descr,
      min_vert_under_ref_feature,
      min_vert_under_ref_feature_descr,
      b.mtrns_asset_no_source,
      b.mtrns_asset_source,
      b.mtrns_asset_key_source,
      b.location_type,
      b.ne_id_of,
      b.pointer_feature
    FROM
      (
        SELECT
          *
        FROM
          ibridges
        WHERE
          min_vert_under_ref_feature IS NOT NULL
      )
      a
    LEFT OUTER JOIN
      (
        SELECT
          bridge_id AS bridge_number,
          iit_ne_id AS mtrns_asset_no_source,
          'BRPT'    AS mtrns_asset_source,
          iit_ne_id
          || '-BRPT' AS mtrns_asset_key_source,
          location_type,
          ne_id_of,
          feature_on_structure AS pointer_feature
        FROM
          v_nm_brpt_nw@metrans
        WHERE
          iit_end_date IS NULL
        UNION ALL
        SELECT
          v_nm_brdg_nw AS bridge_number,
          iit_ne_id    AS mtrns_asset_no_source,
          'BRDG'       AS mtrns_asset_source,
          iit_ne_id
          || '-BRDG' AS mtrns_asset_key_source,
          'B'        AS location_type,
          ne_id_of,
          feature_under_structure AS pointer_feature
        FROM
          v_nm_brdg_nw@metrans
        WHERE
          iit_end_date IS NULL
      )
      b
    ON
      a.bridge_number = b.bridge_number
  );
