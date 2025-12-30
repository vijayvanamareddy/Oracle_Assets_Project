CREATE OR REPLACE VIEW WH_ASSETS.V_BNS_POSTED_BRIDGES
BEQUEATH DEFINER
AS 
WITH bridge_conversions
        AS (SELECT bridge_number, LPAD (county, 3, '0') AS county_padded
              FROM ibridges)
   SELECT b.BRIDGE_number AS BRIDGE_NUM,
          b.BRIDGE_NAME AS BRDG_NAME,
          b.towncode || ' ' || town_name1 AS town1,
          b.town_name1 AS TOWN1_NAME,
          CASE
             WHEN b.towncode2 = '999' THEN ''
             ELSE b.towncode2 || ' ' || town_name2
          END
             AS town2,
          CASE WHEN b.town_name2 = '' THEN 'No Town 2' ELSE b.town_name2 END
             AS TOWN2_NAME,
          b.owner AS owner,
          /*CASE
             when b.owner_descr ='03 - Town or Township Highway Agency'  then 'Town/Township Hwy Agency'
             when b.owner_descr = '26 - Private (other than railroad)' then '26 Private(nonRailroad)'
             WHEN b.owner_descr IS NOT NULL

             THEN
                TRIM (REGEXP_SUBSTR (b.owner_descr,
                                     '[^-]+',
                                     1,
                                     2))
             ELSE
                NULL
          END
             AS owner_desc,*/
          b.owner_descr AS owner_desc,
          b.userbrdg_owner AS owner_tide,
          b.userbrdg_owner_descr AS owner_desc_tide,
          b.MAINTAINER AS CUSTODIAN,
          /*CASE
            when b.maintainer_descr ='03 - Town or Township Highway Agency'  then 'Town/Township Hwy Agency'
            when b.maintainer_descr = '26 - Private (other than railroad)' then '26 Private(nonRailroad)'
             WHEN b.maintainer_descr IS NOT NULL
             THEN
                TRIM (REGEXP_SUBSTR (b.maintainer_descr,
                                     '[^-]+',
                                     1,
                                     2))
             ELSE
                NULL
          END
             AS cust_desc,*/
          b.maintainer_descr AS cust_desc,
          b.userbrdg_maintainer AS custodian_tide,
          b.userbrdg_maintainer_descr AS custodian_desc_tide,
          CASE
             WHEN REGEXP_LIKE (posted_bridge_indicator, '^-?[[:digit:],.]*$')
             THEN
                CAST (posted_bridge_indicator AS NUMBER)
             ELSE
                NULL
          END
             AS post_status,
          posted_bridge_indicator_descr AS post_desc,
          TRIM (SUBSTR (posted_bridge_indicator_descr, 2)) AS D_POST_STA,
          CASE
             WHEN REGEXP_LIKE (post_type, '^-?[[:digit:],.]*$')
             THEN
                CAST (post_type AS NUMBER)
             ELSE
                NULL
          END
             AS post_type,
          post_type_descr AS type_desc,
          TRIM (SUBSTR (post_type_descr, 2)) AS D_POST_TYP,
          lu3.description AS county_desc,
          county_name,
          feature_on_structure AS facility,
          feature_under_structure AS featint,
          vehicle_load_limit AS vh_mton,
          truck_weight_post_limit AS tk_mton,
          ROUND (vehicle_load_limit / .90718472, 5) vh_ton,
          ROUND (truck_weight_post_limit / .90718472, 5) tk_ton,
          --ROUND (operating_rating * .90718472, 3) AS or_mton,
          --ROUND (inventory_rating * .90718472, 3) AS ir_mton,
          operating_rating AS or_ton,
          inventory_rating AS ir_ton
     FROM ibridges b
          LEFT OUTER JOIN bridge_conversions bc
             ON b.bridge_number = bc.bridge_number
          LEFT OUTER JOIN ext_bridge_lookups lu3
             ON lu3.code = bc.county_padded AND lu3.FIELD_ID = '2000300'
    WHERE (posted_bridge_indicator = '3' OR posted_bridge_indicator = '2');
