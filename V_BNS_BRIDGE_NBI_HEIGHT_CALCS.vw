CREATE OR REPLACE VIEW WH_ASSETS.V_BNS_BRIDGE_NBI_HEIGHT_CALCS
BEQUEATH DEFINER
AS 
SELECT
    bridge_number,
    CASE
      WHEN REGEXP_LIKE (type_of_service_on, '^-?[[:digit:],.]*$')
      THEN CAST (type_of_service_on AS NUMBER)
      ELSE NULL
    END                      AS SERVICE_TYPE_ON,
    type_of_service_on_descr AS service_type_on_desc,
    CASE
      WHEN REGEXP_LIKE (type_of_service_under, '^-?[[:digit:],.]*$')
      THEN CAST (type_of_service_under AS NUMBER)
      ELSE NULL
    END                         AS SERVICE_TYPE_UNDER,
    type_of_service_under_descr AS service_type_under_desc,
    CASE
      WHEN ROUND (b.VEHICLE_HEIGHT_UNDER, 1) >= 99.9
      THEN b.VEHICLE_HEIGHT_UNDER
      WHEN b.VEHICLE_HEIGHT_UNDER = -1
      THEN 99.9
      ELSE b.VEHICLE_HEIGHT_UNDER
    END AS vun_nbi_54b, --use the BRIDGE_FIELDMAPPINGS object
    CASE
      WHEN ROUND (VEHICLE_HEIGHT_UNDER, 1) >= 99.9
      THEN VEHICLE_HEIGHT_UNDER
      WHEN VEHICLE_HEIGHT_UNDER = -1
      THEN 99.9
      WHEN VEHICLE_HEIGHT_UNDER = 0
      THEN 99.9
      ELSE ((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12
    END AS VUN_INCHES_nbi_54b,
    CASE
      WHEN ROUND (VEHICLE_HEIGHT_UNDER, 1) >= 99.9
      THEN ''
      WHEN VEHICLE_HEIGHT_UNDER = -1
      OR VEHICLE_HEIGHT_UNDER  IS NULL
      THEN ''
      WHEN VEHICLE_HEIGHT_UNDER = 0
      THEN ''
      WHEN ROUND ( MOD (((VEHICLE_HEIGHT_UNDER)    - (2 / 12)) * 12, 12)) = 0
      THEN CAST ( FLOOR ( (((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12) / 12) AS
        VARCHAR (3))
        || ' FT '
      ELSE CAST ( FLOOR ( (((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12) / 12) AS
        VARCHAR (3))
        || ' FT '
        || CAST ( ROUND ( MOD (((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12, 12))
        AS VARCHAR (3))
        || ' IN'
    END AS VUN_SIGN_POSTING_nbi54b,
    CASE
      WHEN ROUND (VEHICLE_HEIGHT_UNDER, 1) >= 99.9
      THEN VEHICLE_HEIGHT_UNDER
      WHEN VEHICLE_HEIGHT_UNDER = -1
      THEN 99.9
      WHEN VEHICLE_HEIGHT_UNDER = 0
      THEN 99.9
      WHEN ROUND ( MOD ((((VEHICLE_HEIGHT_UNDER) - (2 / 12)) * 12), 12)) = 0
      THEN FLOOR (((VEHICLE_HEIGHT_UNDER)        - (2 / 12)) * 12)
      ELSE ( (FLOOR ( (((VEHICLE_HEIGHT_UNDER)   - (2 / 12)) * 12) / 12)) * 12)
                                                 + ROUND ( MOD (((
        VEHICLE_HEIGHT_UNDER)                    - (2 / 12)) * 12, 12))
    END AS VUN_SIGN_POSTING_IN_nbi54b,
    CASE
      WHEN ROUND (VEHICLE_HEIGHT_OVER, 1) >= 99.9
      THEN VEHICLE_HEIGHT_OVER
      WHEN VEHICLE_HEIGHT_OVER = -1
      THEN 99.9
      WHEN VEHICLE_HEIGHT_OVER = 0
      THEN 99.9
      ELSE VEHICLE_HEIGHT_OVER
    END AS vov_nbi_53,
    CASE
      WHEN ROUND (VEHICLE_HEIGHT_OVER, 1) >= 99.9
      THEN VEHICLE_HEIGHT_OVER
      WHEN VEHICLE_HEIGHT_OVER = -1
      THEN 99.9
      WHEN VEHICLE_HEIGHT_OVER = 0
      THEN 99.9
      ELSE ((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12
    END AS VOV_INCHES_nbi_53,
    CASE
      WHEN ROUND (VEHICLE_HEIGHT_OVER, 1) >= 99.9
      THEN ''
      WHEN VEHICLE_HEIGHT_OVER = -1
      OR vehicle_height_over  IS NULL
      THEN ''
      WHEN VEHICLE_HEIGHT_OVER = 0
      THEN ''
      WHEN ROUND (MOD (((VEHICLE_HEIGHT_OVER)     - (2 / 12)) * 12, 12)) = 0
      THEN CAST ( FLOOR ( (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12) / 12) AS
        VARCHAR (3))
        || ' FT '
      ELSE CAST ( FLOOR ( (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12) / 12) AS
        VARCHAR (3))
        || ' FT '
        || CAST ( ROUND ( MOD (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12, 12)) AS
        VARCHAR (3))
        || ' IN'
    END AS VOV_SIGN_POSTING_nbi_53,
    CASE
      WHEN ROUND (VEHICLE_HEIGHT_OVER, 1) >= 99.9
      THEN VEHICLE_HEIGHT_OVER
      WHEN VEHICLE_HEIGHT_OVER = -1
      THEN 99.9
      WHEN VEHICLE_HEIGHT_OVER = 0
      THEN 99.9
      WHEN ROUND (MOD (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12, 12)) = 0
      THEN FLOOR (((VEHICLE_HEIGHT_OVER)      - (2 / 12)) * 12)
      ELSE ( (FLOOR ( (((VEHICLE_HEIGHT_OVER) - (2 / 12)) * 12) / 12)) * 12) +
        ROUND ( MOD (((VEHICLE_HEIGHT_OVER)   - (2 / 12)) * 12, 12))
    END AS VOV_SIGN_POSTING_IN_nbi_53
  FROM
    ibridges b
  ORDER BY
    bridge_number;
