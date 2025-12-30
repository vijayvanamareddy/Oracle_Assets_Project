CREATE OR REPLACE VIEW WH_ASSETS.ELEMENT_INSPECTIONS
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
             JOIN ibridges b ON e.bridge_id = b.bridge_id
      WHERE e.inspection_date = b.last_routine_inspection_date
    ORDER BY 2;
