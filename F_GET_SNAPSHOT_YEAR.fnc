CREATE OR REPLACE FUNCTION F_GET_SNAPSHOT_YEAR 
-- Looks up max snapshot year 
    RETURN NUMBER 
    DETERMINISTIC                                    
    IS
        SQLMSG   VARCHAR2 (400);
        snap_year NUMBER := NULL;
    BEGIN
        
        SELECT MAX(SNAPSHOT_YEAR)
          INTO snap_year
          FROM COMPLETE_TRANSPORTATION_NETWORK;
       RETURN snap_year;  
       
       EXCEPTION 
             WHEN NO_DATA_FOUND THEN
               return NULL;  
             WHEN OTHERS THEN
                SQLMSG := SUBSTR(SQLERRM,1,400);     
                INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                VALUES (SYSDATE,'F_Get_Snapshot_Year', 'WH_ASSETS',SQLMSG);
                COMMIT; 
    END;
/
