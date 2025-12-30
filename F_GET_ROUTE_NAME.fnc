CREATE OR REPLACE FUNCTION F_Get_Route_Name (rte_no    IN     VARCHAR2)
    RETURN VARCHAR2                                     
    IS
        SQLMSG   VARCHAR2 (400);
        rte_name VARCHAR2(240) := NULL;
    BEGIN
        
        SELECT route_name
          INTO rte_name
          FROM wh_common.dim_routes r
         WHERE r.route_number = rte_no;
       RETURN rte_name;  
       
       EXCEPTION 
             WHEN NO_DATA_FOUND THEN
               return '?';  
             WHEN OTHERS THEN
                SQLMSG := SUBSTR(SQLERRM,1,400);     
                INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                VALUES (SYSDATE,'F_get_route_type', 'WH_ASSETS',SQLMSG);
                COMMIT; 
    END;
/
