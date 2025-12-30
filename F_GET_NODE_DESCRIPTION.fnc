CREATE OR REPLACE FUNCTION F_Get_Node_Description (nodeid   IN     VARCHAR2)
    RETURN VARCHAR2                                     
    IS
        SQLMSG   VARCHAR2 (400);
        node_desc VARCHAR2(80) := NULL;
    BEGIN
        
        SELECT node_description
          INTO node_desc
          FROM nodes n
         WHERE n.node_id = nodeid;
       RETURN node_desc;  
       
       EXCEPTION 
             WHEN NO_DATA_FOUND THEN
               return '?';  
             WHEN OTHERS THEN
                SQLMSG := SUBSTR(SQLERRM,1,400);     
                INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                VALUES (SYSDATE,'F_get_node_description', 'WH_ASSETS',SQLMSG);
                COMMIT; 
    END;
/
