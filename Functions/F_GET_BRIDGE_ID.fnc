CREATE OR REPLACE FUNCTION F_Get_Bridge_id (bridge_no    IN     VARCHAR2)
    RETURN NUMBER                                    
    IS
        SQLMSG   VARCHAR2 (400);
        brdg_id  NUMBER := NULL;
    BEGIN
        
        SELECT bridge_id
          INTO brdg_id
          FROM ibridges_history b
         WHERE b.bridge_number = bridge_no AND state = 'CURRENT';
       RETURN brdg_id;  
       
       EXCEPTION 
             WHEN NO_DATA_FOUND THEN
               return '?';  
             WHEN OTHERS THEN
                SQLMSG := SUBSTR(SQLERRM,1,400);     
                INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                VALUES (SYSDATE,'F_Get_Bridge_id', 'WH_ASSETS',SQLMSG);
                COMMIT; 
    END;
/
