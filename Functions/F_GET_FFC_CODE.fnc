CREATE OR REPLACE FUNCTION F_Get_FFC_Code (FFC_DESCR    IN     VARCHAR2)
-- Looks up FFC Code given a description 
    RETURN NUMBER                                     
    IS
        SQLMSG   VARCHAR2 (400);
        tffc_code NUMBER := NULL;
    BEGIN
        
        SELECT ffc_code
          INTO tffc_code
          FROM wh_common.DIM_FED_FUNC_CLASS f
         WHERE f.FFC_DESC = ffc_descr;
       RETURN tffc_code;  
       
       EXCEPTION 
             WHEN NO_DATA_FOUND THEN
               return NULL;  
             WHEN OTHERS THEN
                SQLMSG := SUBSTR(SQLERRM,1,400);     
                INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                VALUES (SYSDATE,'F_Get_FFC_Code', 'WH_ASSETS',SQLMSG);
                COMMIT; 
    END;
/
