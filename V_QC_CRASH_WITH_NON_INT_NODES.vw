CREATE OR REPLACE VIEW WH_ASSETS.V_QC_CRASH_WITH_NON_INT_NODES
BEQUEATH DEFINER
AS 
SELECT MDOTID, 'NODE' LOC_TYPE
        FROM CRASHREPORT@CRASH
       WHERE    MDOTNODE1_CURRENT IN
                    (SELECT NODE
                       FROM MV_NODES@CRASH
                      WHERE     (NODE_DESC LIKE '%Non Int%' OR NODE_DESC LIKE '%Non-Int%')
                            AND NODE_END_YEAR IS NULL)
           AND MDOTNODE2_CURRENT = 0
UNION
SELECT MDOTID, 'ELEMENT' LOC_TYPE
        FROM CRASHREPORT@CRASH
       WHERE    MDOTNODE1_CURRENT IN
                    (SELECT NODE
                       FROM MV_NODES@CRASH
                      WHERE     (NODE_DESC LIKE '%Non Int%' OR NODE_DESC LIKE '%Non-Int%')
                            AND NODE_END_YEAR IS NULL) AND MDOTNODE2_CURRENT <> 0
             OR MDOTNODE2_CURRENT IN
                    (SELECT NODE
                       FROM MV_NODES@CRASH
                      WHERE     (NODE_DESC LIKE '%Non Int%' OR NODE_DESC LIKE '%Non-Int%')
                            AND NODE_END_YEAR IS NULL)
ORDER BY MDOTID;
