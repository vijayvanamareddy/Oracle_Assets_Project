CREATE OR REPLACE PROCEDURE P_Get_Route_Type_System (rte_no    IN     VARCHAR2, rte_type OUT VARCHAR, rte_sys OUT VARCHAR)                                  
    IS
        SQLMSG   VARCHAR2 (400);
-- 9-4-18 SH - Fix up error handling   
    BEGIN
         rte_type := NULL;
        rte_sys   := NULL;
        SELECT route_type, route_system
          INTO rte_type, rte_sys
          FROM wh_common.dim_routes r
         WHERE r.route_number = rte_no;
        
       
       EXCEPTION 
             WHEN NO_DATA_FOUND THEN
               rte_type := '?';
             WHEN OTHERS THEN
                SQLMSG := SUBSTR(SQLERRM,1,400);        
                INSERT INTO WH_COMMON.TBERRLOG  
                (ERR_DATETIME, ERR_MESSAGE, ERR_MODULE, ERR_OID)
                VALUES (SYSDATE,'P_get_route_type_system', 'WH_ASSETS',SQLMSG);
                COMMIT; 
    END;
/
