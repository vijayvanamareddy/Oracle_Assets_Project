CREATE OR REPLACE VIEW WH_ASSETS.V_CSL_BRIDGE_ELEMENT_DATA
BEQUEATH DEFINER
AS 
WITH LASTINSPECTION
         AS (  SELECT bridge_number as BRDGNO, INSPECTION_DATE AS LAST_INSPDATE
                 FROM IBRIDGES
             )
      SELECT DISTINCT
             BRDGELE.BRIDGE_NUMBER AS BRDGNO,
             LSTINSP.LAST_INSPDATE,
             BRDGELE.CONDITION_STATE1,
             BRDGELE.CONDITION_STATE2,
             BRDGELE.CONDITION_STATE3,
             BRDGELE.CONDITION_STATE4,
             (  (  (1 * BRDGELE.CONDITION_STATE1)
                 + (2 * BRDGELE.CONDITION_STATE2)
                 + (3 * BRDGELE.CONDITION_STATE3)
                 + (4 * BRDGELE.CONDITION_STATE4))
              / 100)
                 AS AVERAGE_CONDITION,
             BRDGELE.ELEMENT_NUMBER,
             CASE
                 WHEN ELEMENT_NUMBER IN (388)
                 THEN
                     'PAINT'
                 WHEN ELEMENT_NUMBER IN (300,
                                  301,
                                  302,
                                  303,
                                  304)
                 THEN
                     'JOINT'
                 WHEN ELEMENT_NUMBER IN (510,840)---(383, 384, 385)Old values in PONTIS?????
                 THEN
                     'WEARING SURFACE'
             END
                 AS ELEMENT_TYPE
        FROM ELEMENT_INSPECTION_HISTORY BRDGELE
             JOIN LASTINSPECTION LSTINSP
                 ON     BRDGELE.BRIDGE_NUMBER = LSTINSP.BRDGNO
                    AND BRDGELE.INSPECTION_DATE = LSTINSP.LAST_INSPDATE
       WHERE     BRDGELE.ELEMENT_NUMBER IN (300,
                                     301,
                                     302,
                                     303,
                                     304,
                                     382,
                                     383,
                                     384,
                                     385,
                                     388)             
    ORDER BY BRDGNO, ELEMENT_NUMBER;
