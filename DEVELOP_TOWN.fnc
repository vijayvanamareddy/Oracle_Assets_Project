CREATE OR REPLACE FUNCTION DEVELOP_TOWN(p_element_id IN NUMBER)
      RETURN VARCHAR2 IS
      
        /*  Revision History:
      7/10/15 - SH - modified to use nm_members_all to pick up towns on end-dated elements, removed check for null end date
      sinplified join
      */
      
      local_town          varchar2(240);
      sqlmsg             varchar2(4000);
    BEGIN
         select distinct   e.ne_descr into local_town
         from nm_members_all@metrans m, nm_elements_all@metrans e
         where m.nm_ne_id_of = p_element_id and
               m.nm_ne_id_IN = e.ne_id AND
               m.NM_OBJ_TYPE in ('TOWN') ;
               return local_town;     
           
    
    
        
         exception 
             when no_data_found then
               return 'NotFound';  
             when others then
                SQLMSG := SUBSTR(SQLERRM,1,400);        
                INSERT INTO WH_COMMON.TBERRLOG  
                (ERR_DATETIME, ERR_MESSAGE, ERR_MODULE, ERR_OID)
                VALUES (SYSDATE,'Develop_TOWN function', 'WH_ASSETS',SQLMSG);
                COMMIT; 
         end;
/
