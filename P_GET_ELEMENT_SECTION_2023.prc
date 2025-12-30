CREATE OR REPLACE PROCEDURE P_Get_Element_Section_2023 (rte_no IN  VARCHAR2, mp IN NUMBER, ele_id OUT NUMBER, ofset OUT NUMBER, sec_id OUT NUMBER, bmp OUT NUMBER, emp OUT NUMBER)                                  
    IS
     
/*
 02-22-2024 SH Gets the element_id, offset, and section_id, begin_section_mp, end_section_mp from the complete_transportation_network based on a route number and milepoint
               Used to add project locations for cross culverts where the source is projex  DOTDW-899
               Note the data may not be segmented on the milepoints (ie where a cross culvert is located)
 03-25-2024 SH Use to add 2023 project locations (run once)
*/
   SQLMSG   VARCHAR2 (400);
   yr       NUMBER;
   cntr     NUMBER;
    BEGIN
        ele_id := NULL;
        ofset   := NULL;
        sec_id  := NULL;
        bmp :=NULL;
        emp := NULL;
        
        yr := 2023;
        
        SELECT COUNT(*) INTO cntr FROM -- is milepoint on a section boundary?
        V_COMPLETE_TRANSP_NETWORK where route_number = rte_no and 
        snapshot_year = yr and mp >=  begin_section_mp and mp <= end_section_mp ;
        
        IF cntr = 1 THEN -- not on a section boundary or mp of 0 or max(mp)
            select element_id,  (mp - begin_element_milepoint), section_id, begin_section_mp, end_section_mp 
            into ele_id, ofset, sec_id, bmp, emp
            from V_COMPLETE_TRANSP_NETWORK where route_number = rte_no and 
            snapshot_year = yr and mp >=  begin_section_mp and mp <= end_section_mp;
        END IF ;
       
           IF cntr = 2 THEN -- on a section boundary, choose the low mp section
            select element_id,  (mp - begin_element_milepoint), section_id , begin_section_mp, end_section_mp 
            into ele_id, ofset, sec_id, bmp, emp
            from V_COMPLETE_TRANSP_NETWORK where route_number = rte_no and 
            snapshot_year = yr and mp >=  begin_section_mp and mp < end_section_mp;
        END IF ;
        
        IF cntr = 0 THEN -- no milepoint on route
                 ele_id := NULL;
                 ofset   := NULL;
                 sec_id  := NULL;
                  bmp :=NULL;
                  emp := NULL;
       END IF;
       
       EXCEPTION 
            
             WHEN OTHERS THEN
                SQLMSG := SUBSTR(SQLERRM,1,400);        
                INSERT INTO WH_COMMON.TBERRLOG  
                (ERR_DATETIME, ERR_MESSAGE, ERR_MODULE, ERR_OID)
                VALUES (SYSDATE,'P_Get_Element_Section', 'WH_ASSETS',SQLMSG);
                COMMIT; 
    END;
/
