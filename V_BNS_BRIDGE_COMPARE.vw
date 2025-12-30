CREATE OR REPLACE VIEW WH_ASSETS.V_BNS_BRIDGE_COMPARE
BEQUEATH DEFINER
AS 
WITH
        metransbridges
        AS
            (SELECT bridge_id AS brdgno FROM v_nm_bros@METRANS
             UNION ALL
             SELECT v_nm_brdg_nw AS brdgo FROM V_NM_BRDG_NW@METRANS),
        enddatedmetransbridges
        AS
            (  SELECT MAX (iit_ne_id)  AS iit_ne_id,
                      IIT_INV_TYPE,
                      IIT_CHR_ATTRIB26,
                      MAX (iit_end_date) AS max_end_date
                 FROM nm_inv_items_all@metrans a
                WHERE     IIT_INV_TYPE = 'BRDG'
                      AND iit_end_date IS NOT NULL
                      AND iit_chr_attrib26 NOT IN
                              (SELECT iit_chr_attrib26
                                 FROM nm_inv_items_all@metrans
                                WHERE     iit_inv_type = 'BRDG'
                                      AND iit_end_date IS NULL)
             GROUP BY iit_inv_type, IIT_CHR_ATTRIB26
             ORDER BY iit_chr_attrib26),
        bridgegeom
        AS
            (SELECT a.ne_id,
                    A.NE_ID_OF,
                    a.end_date,
                    a.GPS_EASTING,
                    a.GPS_NORTHING
               FROM v_bns_bridge@metrans a
              WHERE a.ne_id IN (SELECT iit_ne_id FROM enddatedmetransbridges)),
        bridgegeommax
        AS
            (  SELECT MAX (end_date) AS max_end_date,
                      MAX (NE_ID_OF) AS MAX_NE_ID_OF,
                      ne_id
                 FROM bridgegeom
             GROUP BY ne_id),
        finalbridgewithgeom
        AS
            (SELECT a.*
               FROM bridgegeom  a
                    JOIN bridgegeommax b
                        ON     b.ne_id = a.ne_id
                           AND a.end_date = b.max_end_date
                           AND A.NE_ID_OF = B.MAX_NE_ID_OF),
        METRANSHISTORIC
        AS
            (SELECT a.*,
                    b.*,
                    C.IIT_CHR_ATTRIB27,
                    C.IIT_CHR_ATTRIB28,
                    C.IIT_CHR_ATTRIB29
               FROM enddatedmetransbridges  a
                    JOIN finalbridgewithgeom b ON a.iit_ne_id = b.ne_id
                    JOIN nm_inv_items_all@metrans C ON B.NE_ID = C.IIT_NE_ID)
    SELECT bridge_number,
           CASE
               WHEN b.gps_easting IS NOT NULL THEN 'metrans history'
               ELSE 'inspecttech only'
           END
               AS Source,
           bridge_name,
           towncode || ' ' || town_name1
               AS town1,
           town_name1
               AS TOWN1_NAME,
           CASE
               WHEN towncode2 = '999' THEN ''
               ELSE towncode2 || ' ' || town_name2
           END
               AS town2,
           CASE WHEN town_name2 = '' THEN 'No Town 2' ELSE town_name2 END
               AS TOWN2_NAME,
           MAINTAINER,
           maintainer_descr,
           owner,
           owner_descr,
           type_of_service_on_descr,
           type_of_service_under_descr,
           year_built,
           latitude,
           longitude,
           posted_bridge_indicator,
           posted_bridge_indicator_descr,
           post_type_descr,
           bridge_indicator,
           b."IIT_NE_ID",
           b."IIT_INV_TYPE",
           b."IIT_CHR_ATTRIB26",
           b."MAX_END_DATE",
           b."NE_ID",
           b."NE_ID_OF",
           b."END_DATE",
           b."GPS_EASTING",
           b."GPS_NORTHING",
           b."IIT_CHR_ATTRIB27",
           b."IIT_CHR_ATTRIB28",
           b."IIT_CHR_ATTRIB29"
      FROM ibridges
           LEFT OUTER JOIN METRANSHISTORIC b
               ON bridge_number = b.iit_chr_attrib26
     WHERE bridge_number NOT IN (SELECT brdgno FROM metransbridges) --and bridge_indicator = 'S630 - 0'
    UNION
    SELECT v_nm_brdg_nw          AS bridge_number,
           'metrans only BRIDGE' AS Source,
           NULL                  AS bridge_name,
           NULL                  AS town1,
           NULL                  AS TOWN1_NAME,
           NULL                  AS town2,
           NULL                  AS TOWN2_NAME,
           NULL                  AS MAINTAINER,
           NULL                  AS maintainer_descr,
           NULL                  AS owner,
           NULL                  AS owner_descr,
           NULL                  AS type_of_service_on_descr,
           NULL                  AS type_of_service_under_descr,
           NULL                  AS year_built,
           NULL                  AS latitude,
           NULL                  AS longitude,
           NULL                  AS posted_bridge_indicator,
           NULL                  AS posted_bridge_indicator_descr,
           NULL                  AS post_type_descr,
           NULL                  AS bridge_indicator,
           NULL                  AS IIT_NE_ID,
           NULL                  AS IIT_INV_TYPE,
           NULL                  AS IIT_CHR_ATTRIB26,
           NULL                  AS MAX_END_DATE,
           NULL                  AS NE_ID,
           NE_ID_OF,
           NULL                  AS END_DATE,
           NULL                  AS GPS_EASTING,
           NULL                  AS GPS_NORTHING,
           NULL                  AS IIT_CHR_ATTRIB27,
           NULL                  AS IIT_CHR_ATTRIB28,
           NULL                  AS IIT_CHR_ATTRIB29
      FROM v_nm_brdg_nw@metrans m
     WHERE v_nm_brdg_nw NOT IN (SELECT bridge_number FROM ibridges)
    UNION
    SELECT bridge_id           AS bridge_number,
           'metrans only BROS' AS Source,
           NULL                AS bridge_name,
           NULL                AS town1,
           NULL                AS TOWN1_NAME,
           NULL                AS town2,
           NULL                AS TOWN2_NAME,
           NULL                AS MAINTAINER,
           NULL                AS maintainer_descr,
           NULL                AS owner,
           NULL                AS owner_descr,
           NULL                AS type_of_service_on_descr,
           NULL                AS type_of_service_under_descr,
           NULL                AS year_built,
           NULL                AS latitude,
           NULL                AS longitude,
           NULL                AS posted_bridge_indicator,
           NULL                AS posted_bridge_indicator_descr,
           NULL                AS post_type_descr,
           NULL                AS bridge_indicator,
           NULL                AS IIT_NE_ID,
           NULL                AS IIT_INV_TYPE,
           NULL                AS IIT_CHR_ATTRIB26,
           NULL                AS MAX_END_DATE,
           NULL                AS NE_ID,
           NULL                AS NE_ID_OF,
           NULL                AS END_DATE,
           NULL                AS GPS_EASTING,
           NULL                AS GPS_NORTHING,
           NULL                AS IIT_CHR_ATTRIB27,
           NULL                AS IIT_CHR_ATTRIB28,
           NULL                AS IIT_CHR_ATTRIB29
      FROM v_nm_bros@metrans
     WHERE bridge_id NOT IN (SELECT bridge_number FROM ibridges)
    ORDER BY bridge_number ASC;
