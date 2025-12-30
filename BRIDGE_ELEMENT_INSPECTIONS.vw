CREATE OR REPLACE VIEW WH_ASSETS.BRIDGE_ELEMENT_INSPECTIONS
BEQUEATH DEFINER
AS 
SELECT E.BRIDGE_ID,
             E.BRIDGE_NAME,
             E.BRIDGE_NUMBER,
             E.CONDITION_STATE1,
             E.CONDITION_STATE2,
             E.CONDITION_STATE3,
             E.CONDITION_STATE4,
             E.ELEMENT_NAME,
             E.ELEMENT_NUMBER,
             E.ELEMENT_PARENT_NAME,
             E.ELEMENT_PARENT_NUMBER,
             E.ENVIRONMENT,
             E.INSPECTION_DATE,
             e.INSPECTION_ID,
             E.TOT_QTY,
             E.UOM
        FROM element_inspection_history e
             JOIN bridge_INSPECTION_HISTORY b ON e.bridge_NUMBER = b.bridge_NUMBER AND
                  B.INSPECTION_DATE = E.INSPECTION_DATE 
       WHERE B.INSPECTION_TYPE LIKE '%1%' -- ROUTINE
            OR B.INSPECTION_TYPE LIKE '%4%'  -- SPECIAL
    ORDER BY 3;
