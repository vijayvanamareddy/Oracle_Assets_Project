CREATE OR REPLACE VIEW WH_ASSETS.V_MIRE_INTERSECTION
BEQUEATH DEFINER
AS 
SELECT HSM.NODE_ID                          UNIQUE_JUNCTION_IDENTIFIER,
           HSM.NODE_PRIMARYRT                   LOCATION_IDENTIFIER_1_ROUTE,
           HSM.NODE_MPS                         LOCATION_IDENTIFIER_1_MILEPOINT,
           CASE
               WHEN HSM.NODE_PRIMARYRT = HSM.LINK_PRIMARYRT THEN NULL
               WHEN HSM.NODE_EMP = 0 THEN NULL
               ELSE HSM.LINK_PRIMARYRT
           END                                  LOCATION_IDENTIFIER_2_ROUTE,
           CASE
               WHEN HSM.NODE_PRIMARYRT = HSM.LINK_PRIMARYRT THEN NULL
               WHEN HSM.NODE_EMP = 0 THEN NULL
               ELSE HSM.NODE_EMP
           END                                  LOCATION_IDENTIFIER_2_MILEPOINT,
           CASE
               WHEN HSM.SUM_INCNT = 0
               THEN
                   'END OR ONEWAY'
               WHEN HSM.SUM_INCNT = 1 AND HSM.THRUTYPERD_DESC = 'Rotary'
               THEN
                   'ROTARY'
               WHEN HSM.SUM_INCNT = 1
               THEN
                   'END OR ONEWAY'
               WHEN HSM.SUM_INCNT = 2 AND HSM.THRUTYPERD_DESC = 'Undivided'
               THEN
                   'NON-INTERSECTION'
               WHEN HSM.SUM_INCNT = 2 AND HSM.THRUTYPERD_DESC = 'Divided'
               THEN
                   'DIVIDED'
               WHEN HSM.SUM_INCNT = 2 AND HSM.THRUTYPERD_DESC = 'Rotary'
               THEN
                   'ROTARY'
               WHEN HSM.SUM_INCNT = 3
               THEN
                   'T-INTERSECTION'
               WHEN HSM.SUM_INCNT = 4
               THEN
                   'CROSS-INTERSECTION'
               WHEN HSM.SUM_INCNT >= 5
               THEN
                   'FIVE OR MORE LEGS AND NOT CIRCULAR'
           END                                  INTERSECTION_GEOMETRY,
           HSM.SUM_INCNT                        APPROACH_COUNT,
           HSM.LEG_ANGLE                        APPROACH_ANGLE,
           FACILITY_TYPE_DESC                   TRAFFIC_CONTROL,
           HSM.DESCRIPTION                      APPROACH_DESCRIPTION,
           HSM.THRUTYPERD_DESC                  APPROACH_MEDIAN_TYPE,
           HSM.FAADT                            APPROACH_ADDT,
           HSM.AADTYRFACT                       APPROACH_AADT_YEAR,
           CONCAT (HSM.LINK_ID, HSM.NODE_ID)    UNIQUE_APPROACH_IDENTIFIER
      FROM HSM_LINES@GIS  HSM
           LEFT OUTER JOIN HSM_LU@GIS HSML
               ON     HSM.SIGNALIZED = HSML.SIGNAL
                  AND ST_URBRUR = URBAN
                  AND SUM_INCNT = NUM_LEGS;
