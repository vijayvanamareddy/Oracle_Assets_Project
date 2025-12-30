CREATE OR REPLACE VIEW WH_ASSETS.V_BNS_CSL_LANEDEPARTURE
BEQUEATH DEFINER
AS 
WITH
        DISTRACTED_DRIVERS
        AS
            (  SELECT COUNT (mdotID) AS DISTRACTED_DRIVER_COUNT,
                      MDOTID       AS CRASH_ID
                 FROM ACCIDENT_PEOPLE
                WHERE     PERSON_TYPE IN (1, 6)
                      AND DRIVER_DISTRACTED IN (2,
                                                3,
                                                4,
                                                5)
             GROUP BY MDOTID
             ORDER BY DISTRACTED_DRIVER_COUNT DESC),
        Linksfornodecount
        AS
            (SELECT DISTINCT ELEMENT_ID, BEGIN_NODE_ID, end_node_ID
               FROM element_history
              WHERE     end_date IS NULL
                    AND factor_group NOT IN ('RR', 'TR', 'FR')),
        nodecount
        AS
            (  SELECT BEGIN_NODE_ID       AS BEG_NODE,
                      COUNT (BEGIN_NODE_ID) AS COUNT_NODE
                 FROM linksfornodecount
             GROUP BY BEGIN_NODE_ID
             UNION ALL
               SELECT END_NODE_ID       AS BEG_NODE,
                      COUNT (END_NODE_ID) AS COUNT_NODE
                 FROM linksfornodecount
             GROUP BY END_NODE_ID),
        nodecountfinal
        AS
            (  SELECT nodecount.beg_node, SUM (count_node) AS node_cnt
                 FROM nodecount
             GROUP BY nodecount.beg_node
             ORDER BY node_cnt DESC),
        oneelementsetup
        AS
            (SELECT element_id,
                    node_id,
                    offset,
                    ROWNUM AS rn
               FROM (SELECT begin_node_id AS node_id,
                            0             AS offset,
                            'BEGIN'       AS offset_type,
                            element_id
                       FROM elements
                      WHERE factor_group NOT IN ('RR', 'TR', 'FR')
                     UNION
                     SELECT end_node_id    AS node_id,
                            element_length AS offset,
                            'END'          AS offset_type,
                            element_id
                       FROM elements
                      WHERE factor_group NOT IN ('RR', 'TR', 'FR'))),
        minelement
        AS
            (  SELECT MIN (rn) AS min_rn, node_id
                 FROM oneelementsetup
             GROUP BY node_id),
        ACCIDENTSETUP
        AS
            (  SELECT CASE
                          WHEN (UPPER (a.MDOTID) LIKE '%C')
                          THEN
                                 SUBSTR (a.MDOTID, 1, 5)
                              || LPAD (SUBSTR (a.MDOTID, 6), 6, '0')
                          ELSE
                                 SUBSTR (a.MDOTID, 1, 5)
                              || LPAD (SUBSTR (a.MDOTID, 6), 5, '0')
                      END
                          AS crash_id,
                      a.MDOTID,
                      a.ACCident_YEAR
                          AS CRASH_YEAR,
                      ACCIDENT_DATE,
                      a.TYPE_of_CRASH_descr
                          AS TYPE_OF_CRASH,
                      LOCATION_TYPE,
                      ELEMENT_ID,
                      CASE a.road_surf_cond
                          WHEN 3 THEN 'WINTER'
                          WHEN 4 THEN 'WINTER'
                          WHEN 5 THEN 'WINTER'
                          WHEN 1 THEN 'DRY'
                          WHEN 2 THEN 'WET'
                          WHEN 6 THEN 'WET'
                          ELSE 'OTHER'                         --(7,8,9,10,11)
                      END
                          AS ROAD_CONDITION,
                      CASE light_condition
                          WHEN 1 THEN 'DAY'
                          WHEN 2 THEN 'NIGHT'
                          WHEN 3 THEN 'NIGHT'
                          WHEN 4 THEN 'NIGHT'
                          WHEN 5 THEN 'NIGHT'
                          WHEN 6 THEN 'NIGHT'
                          ELSE 'OTHER'                                   --(7)
                      END
                          AS LIGHT_CONDITION,
                      CASE weather_condition
                          WHEN 3 THEN 'VISIBILITY'
                          WHEN 7 THEN 'VISIBILITY'
                          WHEN 9 THEN 'VISIBILITY'
                          WHEN 4 THEN 'PRECIPITATION'
                          WHEN 5 THEN 'PRECIPITATION'
                          WHEN 6 THEN 'PRECIPITATION'
                          WHEN 1 THEN 'DRY'
                          WHEN 2 THEN 'DRY'
                          ELSE 'OTHER'                                    --10
                      END
                          AS WEATHER_CONDITION,
                      CASE a.accident_DAY_OF_WEEK_num
                          WHEN 1 THEN 'WEEKEND'
                          WHEN 7 THEN 'WEEKEND'
                          ELSE 'WEEKDAY'
                      END
                          AS WEEKPORTION,
                      CASE
                          WHEN (    EXTRACT (MONTH FROM a.ACCIDENT_DATE) <= 3
                                AND EXTRACT (DAY FROM a.ACCIDENT_DATE) < 21)
                          THEN
                              'WINTER'
                          WHEN (    EXTRACT (MONTH FROM a.ACCIDENT_DATE) = 3
                                AND EXTRACT (DAY FROM a.ACCIDENT_DATE) >= 21)
                          THEN
                              'SPRING'
                          WHEN EXTRACT (MONTH FROM a.ACCIDENT_DATE) = 4
                          THEN
                              'SPRING'
                          WHEN EXTRACT (MONTH FROM a.ACCIDENT_DATE) = 5
                          THEN
                              'SPRING'
                          WHEN (    EXTRACT (MONTH FROM a.ACCIDENT_DATE) = 6
                                AND EXTRACT (DAY FROM a.ACCIDENT_DATE) < 22)
                          THEN
                              'SPRING'
                          WHEN (    EXTRACT (MONTH FROM a.ACCIDENT_DATE) = 6
                                AND EXTRACT (DAY FROM a.ACCIDENT_DATE) >= 22)
                          THEN
                              'SUMMER'
                          WHEN EXTRACT (MONTH FROM a.ACCIDENT_DATE) = 7
                          THEN
                              'SUMMER'
                          WHEN EXTRACT (MONTH FROM a.ACCIDENT_DATE) = 8
                          THEN
                              'SUMMER'
                          WHEN (    EXTRACT (MONTH FROM a.ACCIDENT_DATE) = 9
                                AND EXTRACT (DAY FROM a.ACCIDENT_DATE) < 23)
                          THEN
                              'SUMMER'
                          WHEN (    EXTRACT (MONTH FROM a.ACCIDENT_DATE) = 9
                                AND EXTRACT (DAY FROM a.ACCIDENT_DATE) >= 23)
                          THEN
                              'FALL'
                          WHEN EXTRACT (MONTH FROM a.ACCIDENT_DATE) = 10
                          THEN
                              'FALL'
                          WHEN EXTRACT (MONTH FROM a.ACCIDENT_DATE) = 11
                          THEN
                              'FALL'
                          WHEN (    EXTRACT (MONTH FROM a.ACCIDENT_DATE) = 12
                                AND EXTRACT (DAY FROM a.ACCIDENT_DATE) < 22)
                          THEN
                              'FALL'
                          ELSE
                              'WINTER'
                      END
                          AS SEASON,
                      a.workzone_in_or_near_descr
                          AS WORKZONE,
                      CASE
                          WHEN A.workzone_in_or_near_descr = 'Yes' THEN 1
                          ELSE 0
                      END
                          AS WRKZN,
                      a.OFFSET,
                      a.NODE_ID,
                      a.element_id
                          AS CRASH_ELEMENT,
                      a.offset
                          AS CRASH_OFFSET,
                      CASE WHEN a.no_of_k_inj = 0 THEN 0 ELSE 1 END
                          AS FATAL,
                      SUM (a.NO_OF_K_INJ)
                          AS SUM_NO_OF_K_INJ,
                      SUM (a.NO_OF_A_INJ)
                          AS SUM_NO_OF_A_INJ,
                      SUM (a.NO_OF_B_INJ)
                          AS SUM_NO_OF_B_INJ,
                      SUM (a.NO_OF_C_INJ)
                          AS SUM_NO_OF_C_INJ,
                      CASE
                          WHEN b.DISTRACTED_DRIVER_COUNT IS NULL THEN 0
                          ELSE B.DISTRACTED_DRIVER_COUNT
                      END
                          AS DISTRACTEDDRIVERCOUNT,
                      CASE
                          WHEN b.DISTRACTED_DRIVER_COUNT IS NULL THEN 0
                          ELSE 1
                      END
                          AS DISTRACTEDDRIVER
                 FROM accidents a
                      LEFT OUTER JOIN DISTRACTED_DRIVERS b
                          ON a.mdotid = b.crash_id
                WHERE TYPE_of_CRASH_descr IN
                          ('Head-on / Sideswipe', 'Went Off Road')
             GROUP BY a.MDOTID,
                      a.accident_Year,
                      a.accident_date,
                      a.TYPE_of_CRASH_descr,
                      a.location_type,
                      a.element_id,
                      a.road_surf_cond,
                      a.light_condition,
                      a.weather_condition,
                      a.accident_day_of_week_num,
                      a.accident_date,
                      a.workzone_in_or_near_descr,
                      a.OFFSET,
                      a.NODE_ID,
                      a.ELEMENT_ID,
                      a.OFFSET,
                      a.NO_OF_K_INJ,
                      b.DISTRACTED_DRIVER_COUNT),
        LANEDEPARTURES
        AS
            (  SELECT *
                 FROM (SELECT A.*,
                              d.element_id AS element_id_mapping,
                              d.offset   AS offset_mapping
                         FROM ACCIDENTSETUP A
                              JOIN oneelementsetup d ON d.node_id = A.node_id
                              JOIN minelement c ON d.rn = c.min_rn
                        WHERE     LOCATION_TYPE = 'NODE'
                              AND A.element_id IS NULL
                              AND A.node_id IS NOT NULL
                       UNION ALL
                       SELECT a.*,
                              a.element_id AS element_id_mapping,
                              a.offset   AS offset_mapping
                         FROM ACCIDENTSETUP A
                        WHERE     location_type = 'ELEMENT'
                              AND ELEMENT_ID IS NOT NULL)
             ORDER BY CRASH_YEAR DESC)
    SELECT LANEDEPARTURES."CRASH_ID",
           LANEDEPARTURES.MDOTID
               AS "MDOT_ID",
           CAST (LANEDEPARTURES."CRASH_YEAR" AS NUMBER (9))
               AS crash_year,
           LANEDEPARTURES."ACCIDENT_DATE",
           LANEDEPARTURES."TYPE_OF_CRASH",
           CASE
               WHEN LANEDEPARTURES."LOCATION_TYPE" = 'ELEMENT' THEN 'LINK'
               ELSE LOCATION_TYPE
           END
               AS LOCATION_TYPE,
           CAST (LANEDEPARTURES."ELEMENT_ID" AS NUMBER (9))
               AS element_id,
           LANEDEPARTURES."ROAD_CONDITION",
           LANEDEPARTURES."LIGHT_CONDITION",
           LANEDEPARTURES."WEATHER_CONDITION",
           LANEDEPARTURES."WEEKPORTION",
           LANEDEPARTURES."SEASON",
           LANEDEPARTURES."WORKZONE",
           CAST (LANEDEPARTURES."WRKZN" AS NUMBER (9))
               AS wrkzn,
           LANEDEPARTURES.OFFSET_MAPPING
               AS "OFFSET",
           CAST (LANEDEPARTURES."NODE_ID" AS NUMBER (9))
               AS node_id,
           CAST (LANEDEPARTURES.ELEMENT_ID_MAPPING AS NUMBER (9))
               AS "CRASH_ELEMENT",
           LANEDEPARTURES.OFFSET_MAPPING
               AS "CRASH_OFFSET",
           CAST (LANEDEPARTURES."FATAL" AS NUMBER (9))
               AS fatal,
           CAST (LANEDEPARTURES."SUM_NO_OF_K_INJ" AS NUMBER (9))
               AS sum_no_of_k_inj,
           CAST (LANEDEPARTURES."SUM_NO_OF_A_INJ" AS NUMBER (9))
               AS sum_no_of_a_inj,
           CAST (LANEDEPARTURES."SUM_NO_OF_B_INJ" AS NUMBER (9))
               AS sum_no_of_b_inj,
           CAST (LANEDEPARTURES."SUM_NO_OF_C_INJ" AS NUMBER (9))
               AS sum_no_of_c_inj,
           CAST (LANEDEPARTURES."DISTRACTEDDRIVERCOUNT" AS NUMBER (9))
               AS distracteddrivercount,
           CAST (LANEDEPARTURES."DISTRACTEDDRIVER" AS NUMBER (9))
               AS distracteddriver,
           CAST (nodecountfinal.NODE_CNT AS NUMBER (9))
               AS node_cnt,
           CASE WHEN nodecountfinal.node_cnt <= 2 THEN 'Y' ELSE 'N' END
               AS NonInt,
           CASE
               WHEN r.direction = 1
               THEN
                   r.BEGIN_ELEMENT_MILEPOINT + LANEDEPARTURES.OFFSET_MAPPING --BEGIN SECTION MP ON ROUTE
               WHEN r.direction = -1
               THEN
                   r.END_ELEMENT_MILEPOINT - LANEDEPARTURES.OFFSET_MAPPING
           END
               AS CALC_MP,
           R.ROUTE_NUMBER
               AS RTCODE
      FROM LANEDEPARTURES
           JOIN routes_history r
               ON     LANEDEPARTURES.ELEMENT_ID_MAPPING = r.ELEMENT_ID
                  AND r.PRIMARY = 'Y'
                  AND R.END_DATE IS NULL
           LEFT OUTER JOIN nodecountfinal
               ON LANEDEPARTURES.NODE_ID = nodecountfinal.BEG_NODE
--WHERE CRASH_YEAR=2018 AND LOCATION_TYPE= 'NODE'
;
