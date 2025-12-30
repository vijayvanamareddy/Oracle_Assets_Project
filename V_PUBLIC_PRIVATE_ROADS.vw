CREATE OR REPLACE VIEW WH_ASSETS.V_PUBLIC_PRIVATE_ROADS
BEQUEATH DEFINER
AS 
SELECT XMLSERIALIZE (
               DOCUMENT XMLELEMENT (
                            "DATA",
                            XMLAGG (XMLELEMENT (
                                        "TOWN",
                                        XMLFOREST (
                                            REPLACE ((t.name_of_town),
                                                     ' ',
                                                     '') AS "FILENAME",
                                            t.name_of_town AS "TOWNNAME",
                                            (SELECT XMLAGG (XMLELEMENT (
                                                                "PUBLIC_ROW",
                                                                (XMLFOREST (
                                                                     pub.route_number,
                                                                     pub.town_name,
                                                                     pub.streetname,
                                                                     pub.begin_node_description,
                                                                     pub.begin_node_id,
                                                                     pub.end_node_id,
                                                                     JURISDICTION,
                                                                     end_node_description,
                                                                     county_name,
                                                                     ROUND (
                                                                           end_mp
                                                                         - begin_mp,
                                                                         3)
                                                                         AS "MILES",
                                                                     TO_CHAR (
                                                                         SYSDATE,
                                                                         'MM/DD/YYYY')
                                                                         AS "DATE_RUN")))
                                                            ORDER BY
                                                    (CASE
                                                         WHEN jurisdiction =
                                                              'State Highway'
                                                         THEN
                                                             1
                                                         WHEN jurisdiction =
                                                              'State Aid'
                                                         THEN
                                                             2
                                                         WHEN jurisdiction =
                                                              'Town Maintained Year Round'
                                                         THEN
                                                             3
                                                         WHEN jurisdiction =
                                                              'Town Way Summer'
                                                         THEN
                                                             4
                                                         WHEN jurisdiction =
                                                              'Town Way Winter'
                                                         THEN
                                                             5
                                                         WHEN jurisdiction =
                                                              'Seasonal Parkway'
                                                         THEN
                                                             6
                                                         WHEN jurisdiction =
                                                              'Other'
                                                         THEN
                                                             7
                                                         ELSE
                                                             8
                                                     END),
                                                    pub.streetname)
                                               FROM mv_dissolved_public_roads
                                                    pub
                                              WHERE pub.town_name =
                                                    t.name_of_town)
                                                AS "PUBLIC_ROADS",
                                            (  SELECT XMLAGG (XMLELEMENT (
                                                                  "TOWN_JURISDICTION_TOTALS",
                                                                  (XMLFOREST (
                                                                       TOWN_NAME,
                                                                       JURISDICTION,
                                                                       SUM (
                                                                             END_MP
                                                                           - BEGIN_MP)
                                                                           AS "TOWN_JURISDICTION_PUBLIC_MILEAGE")))
                                                              ORDER BY
                                                      town_name,
                                                      (CASE
                                                           WHEN jurisdiction =
                                                                'State Highway'
                                                           THEN
                                                               1
                                                           WHEN jurisdiction =
                                                                'State Aid'
                                                           THEN
                                                               2
                                                           WHEN jurisdiction =
                                                                'Town Maintained Year Round'
                                                           THEN
                                                               3
                                                           WHEN jurisdiction =
                                                                'Town Way Summer'
                                                           THEN
                                                               4
                                                           WHEN jurisdiction =
                                                                'Town Way Winter'
                                                           THEN
                                                               5
                                                           WHEN jurisdiction =
                                                                'Seasonal Parkway'
                                                           THEN
                                                               6
                                                           WHEN jurisdiction =
                                                                'Other'
                                                           THEN
                                                               7
                                                           ELSE
                                                               8
                                                       END) )
                                                 FROM MV_DISSOLVED_PUBLIC_ROADS
                                                      put
                                                WHERE put.TOWN_NAME =
                                                      t.name_of_town
                                             GROUP BY put.TOWN_NAME,
                                                      JURISDICTION)
                                                AS "TOTAL_TOWN",
                                            (  SELECT XMLAGG (
                                                          XMLELEMENT (
                                                              "TOWN_TOTALS",
                                                              (XMLFOREST (
                                                                   TOWN_NAME,
                                                                   SUM (
                                                                         END_MP
                                                                       - BEGIN_MP)
                                                                       AS "TOWN_PUBLIC_MILEAGE"))))
                                                 FROM MV_DISSOLVED_PUBLIC_ROADS
                                                      pu
                                                WHERE pu.TOWN_NAME =
                                                      t.name_of_town
                                             GROUP BY pu.TOWN_NAME)
                                                AS "TOTAL_TOWN",
                                            (SELECT XMLAGG (
                                                        XMLELEMENT (
                                                            "PRIVATE_ROW",
                                                            (XMLFOREST (
                                                                 RDNAME,
                                                                 TOWN,
                                                                 CASE
                                                                     WHEN LCITY =
                                                                          RCITY
                                                                     THEN
                                                                         LCITY
                                                                     ELSE
                                                                            LCITY
                                                                         || '-'
                                                                         || RCITY
                                                                 END AS CITY,
                                                                 CASE
                                                                     WHEN LCOUNTY =
                                                                          RCOUNTY
                                                                     THEN
                                                                         LCOUNTY
                                                                     ELSE
                                                                            LCOUNTY
                                                                         || '-'
                                                                         || RCOUNTY
                                                                 END
                                                                     AS COUNTY,
                                                                 sum(round(MILES, 2)) as miles_tot_priv)))order by town,rdname)
                                               FROM V_DTGISP_E911_PRIVATE pri
                                              WHERE pri.town = t.name_of_town GROUP BY TOWN, RDNAME, LCITY, RCITY,lCOUNTY,RCOUNTY)
                                                AS "PRIVATE_ROADS",
                                            (  SELECT XMLAGG (
                                                          (XMLFOREST (
                                                               TOWN,
                                                               SUM (MILES)
                                                                   AS "TOTAL_PRIVATE_MILES")))
                                                 FROM V_DTGISP_E911_PRIVATE p
                                                WHERE p.town = t.name_of_town
                                             GROUP BY p.TOWN) AS "TOWN_TOTAL"))
                                    ORDER BY t.name_of_town))
                   AS BLOB
               ENCODING 'UTF-8' VERSION '1.0' INDENT SIZE = 4)    AS XMLCONTENT
      FROM WH_ASSETS.V_PUBLIC_PRIVATE_T0WNS T;
