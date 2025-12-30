CREATE OR REPLACE VIEW WH_ASSETS.V_BRIDGE_PROGRAM
BEQUEATH DEFINER
AS 
SELECT P.BRIDGE_ID,
           P.BRIDGE_NAME,
           P.BRIDGE_NUMBER,
           CE_COST,
           CONSTRUCTION_COST,
           PE_COST,
           PROGRAM_YEAR,
           CASE WHEN ASCII (psn) = 0 THEN 0 ELSE CAST (TRIM (psn) AS INT) END
               AS psn,
           ROW_COST,
           SCOPE,
           TOT_COST,
           COMMENTS,
           TRIM (REASON)
      FROM WH_ASSETS.BRIDGE_PROGRAM_HISTORY  P
           LEFT OUTER JOIN BRIDGE_WORKPLAN_FIELD_REVIEW W
               ON P.BRIDGE_ID = W.BRIDGE_ID;
