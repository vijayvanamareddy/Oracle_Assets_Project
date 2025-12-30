CREATE OR REPLACE PROCEDURE test_route_sections IS

/**********************************************************************
This procedure analyzes the current all_route_sections route network 
and reports on the following errors:

1.  Do all routes start with begin milepoint of 0 (Should be true for all highway routes)
    Does the first section of the first element begin with milepoint 0
2.  Does the end milepoint of each segment = the begin milepoint of the next section in the same element? 
3.  Are there any gaps 
   
    b.  Compares the begin_element_milepoint of the current element with the end_element_milepoint of the prior record
    
It is run after the all_routes_weekly_refresh     

08/04/2015 SH  Initial Version

07-05-2016 SH Modify for TIG Routes
            Add section_length_checks
            Write to data_exceptions table
            Add standard error handling

05-09-2018 SH Modify to test the view, all_route_sections
01-22-2019 SH Modify to test new geospatial segmentation
02-12-2019 SH Modify to use route_sections, rename to test_route_sections 
03-07-2019 SH Write final check to data_exceptions table 
03-27-2019 SH Move from dev to test
**********************************************************************/

BEGIN
DECLARE CURSOR ar IS
SELECT route_number, element_id, section_id,  begin_element_milepoint,  end_element_milepoint, begin_section_mp, end_section_mp, begin_offset, end_offset, cumulative_milepoint_order, route_type
FROM route_sections
ORDER BY  route_number, cumulative_milepoint_order, begin_section_mp;

rec ar%ROWTYPE;

previous_begin_element_mp     route_sections.begin_element_milepoint%TYPE;
previous_end_element_mp       route_sections.end_element_milepoint%TYPE;
previous_cmp                  route_sections.cumulative_milepoint_order%TYPE;
previous_element_id           route_sections.element_id%TYPE;
previous_route_number         route_sections.route_number%TYPE;
previous_end_section_mp       route_sections.end_section_mp%TYPE;

num_routes   NUMBER := 0;
num_elements NUMBER :=0;
element_length NUMBER :=0;
section_length NUMBER;
sum_section_length NUMBER := 0;

err_msg      VARCHAR2(200);
      tab                         VARCHAR2 (30) := 'route_sections';
      test_procedure              VARCHAR2 (30) := 'TEST_ROUTE_SECTIONS';
      rundate                     DATE := SYSDATE;
      col_name1                   VARCHAR2 (30);
      col_val1                    VARCHAR2 (30);
      col_name2                   VARCHAR2 (30);
      col_val2                    VARCHAR2 (30);
      col_name3                   VARCHAR2 (30);
      col_val3                    VARCHAR2 (30);
      col_name4                   VARCHAR2 (30);
      col_val4                    VARCHAR2 (30);
      tname                       VARCHAR2 (100);
      assess                      VARCHAR2 (10);

      cntr                        NUMBER := 0;
      cntr_added                  NUMBER := 0;
      start_time                  DATE := SYSDATE;

      PROCEDURE Write_it (p1    IN VARCHAR,
                          p2    IN VARCHAR,
                          p3    IN NUMBER,
                          p4    IN VARCHAR,
                          p5    IN VARCHAR,
                          p6    IN VARCHAR,
                          p7    IN VARCHAR,
                          p8    IN VARCHAR,
                          p9    IN VARCHAR,
                          p10   IN VARCHAR,
                          p11   IN VARCHAR,
                          p12   IN VARCHAR,
                          p13   IN VARCHAR,
                          p14   IN VARCHAR,
                          p15   IN DATE,
                          p16   IN VARCHAR)
      IS
      BEGIN
         INSERT INTO data_exceptions (TABLE_NAME,
                                      ASSET_ID_COLUMN,
                                      ASSET_ID,
                                      ERROR_CONDITION,
                                      COLUMN_NAME1,
                                      COLUMN_VALUE1,
                                      COLUMN_NAME2,
                                      COLUMN_VALUE2,
                                      COLUMN_NAME3,
                                      COLUMN_VALUE3,
                                      COLUMN_NAME4,
                                      COLUMN_VALUE4,
                                      TEST_NAME,
                                      TEST_PROCEDURE,
                                      TEST_DATE,
                                      ASSESSMENT)
              VALUES (p1,
                      p2,
                      p3,
                      p4,
                      p5,
                      p6,
                      p7,
                      p8,
                      p9,
                      p10,
                      p11,
                      p12,
                      p13,
                      p14,
                      p15,
                      p16);
      END;


BEGIN

    OPEN ar;
  
    FETCH ar INTO rec;  
    
    -- Test for route starting at begin milepoint 0
    -- Does the first element start at 0?
    
     IF rec.begin_element_milepoint <> 0
          THEN 
          IF rec.route_type <> 'T' -- rail routes may not begin at begin_section_mp 0
            THEN
               tname := 'Route Starts at Begin Milepoint 0';
               assess := 'INCORRECT';
               err_msg := 'does not start at 0';
               col_name1 := 'Route Number';
               col_val1 := rec.route_number;
               col_name2 := 'Element ID';
               col_val2 := rec.element_id;
               Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                         NULL,
                         NULL,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);
          END IF;
     END IF;
     
      -- Does the first section start at 0?
      
     IF rec.begin_section_mp <> 0 
     THEN
        IF rec.route_type <> 'T' -- rail routes may not begin at begin_section_mp 0
            THEN 
               tname := 'Route Starts at Begin Milepoint 0';
               assess := 'INCORRECT';
               err_msg := 'Section does not start at 0';
               col_name1 := 'Route Number';
               col_val1 := rec.route_number;
                col_name2 := 'Section ID';
               col_val2 := rec.section_id;
               Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                         NULL,
                         NULL,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);
        END IF;
    END IF;
 
      num_routes := num_routes + 1;
      num_elements := num_elements + 1;
      
      
      element_length := rec.end_element_milepoint - rec.begin_element_milepoint;
      section_length := rec.end_section_mp - rec.begin_section_mp;
      sum_section_length :=  section_length;
      
      
      previous_begin_element_mp := rec.begin_element_milepoint;
      previous_end_element_mp  := rec.end_element_milepoint;
      previous_element_id := rec.element_id;
      previous_route_number := rec.route_number;
      previous_end_section_mp := rec.end_section_mp;
      previous_cmp := rec.cumulative_milepoint_order;
      
      
                                       
LOOP

      FETCH ar INTO rec;  
      EXIT WHEN ar%NOTFOUND;
      
      IF rec.route_number = previous_route_number -- same route?
      THEN  
         
         IF rec.element_id = previous_element_id -- same element?
         THEN -- Section checks
    
            IF rec.begin_section_mp <> previous_end_section_mp
            THEN
              tname := 'Gap in Route by Comparing Mileage';
               assess := 'INCORRECT';
               err_msg :=
                  'begin_section_mp <>  previous_end_section_mp';
               col_name1 := 'Route Number';
               col_val1 := rec.route_number;
               col_name2 := 'Element ID';
               col_val2 := TO_CHAR (previous_element_id);
               col_name3 := 'Section ID';
               col_val3 := TO_CHAR (rec.section_id);
               Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                        col_name3,
                        col_val3,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);
            END IF;     
        
            
            section_length := rec.end_section_mp - rec.begin_section_mp;
            
            IF section_length  <> (rec.end_offset - rec.begin_offset)
            THEN
            tname := 'Section Length Test';
               assess := 'INCORRECT';
               err_msg :=
                  'Section Lengths Differ - end_section_mp - begin_section_mp <> end_ofset - begin_offset';
               col_name1 := 'Route Number';
               col_val1 := rec.route_number;
               col_name2 := 'Element ID';
               col_val2 := TO_CHAR (rec.element_id);
               col_name3 := 'Section ID';
               col_val3 := TO_CHAR (rec.section_id);
               Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                        col_name3,
                        col_val3,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);           
           END IF;        
  
            previous_end_section_mp := rec.end_section_mp;  
            sum_section_length := sum_section_length + section_length;
         ELSE  -- we have a new element
         
             num_elements := num_elements + 1;
      
              IF rec.begin_element_milepoint <>  previous_end_element_mp -- compare mileage
              THEN 
               tname := 'Gap in Route by Comparing Mileage';
               assess := 'INCORRECT';
               err_msg :=
                  'begin_element_milepoint <>  previous_end_element_mp';
               col_name1 := 'Route Number';
               col_val1 := rec.route_number;
               col_name2 := 'Element ID';
               col_val2 := TO_CHAR (previous_element_id);
               Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                         NULL,
                         NULL,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);
            END IF;
                   
             
              IF rec.begin_element_milepoint <>  previous_end_section_mp -- compare mileage
              THEN 
               tname := 'Gap in Route by Comparing Mileage';
               assess := 'INCORRECT';
               err_msg :=
                  'begin_element_milepoint <>  previous_end_section_mp';
               col_name1 := 'Route Number';
               col_val1 := rec.route_number;
               col_name2 := 'Element ID';
               col_val2 := TO_CHAR (previous_element_id);
               Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                         NULL,
                         NULL,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);
                   
             END IF;  
             
            IF     previous_end_section_mp <> previous_end_element_mp
            THEN   
            tname := 'Gap in Route by Comparing Mileage';
               assess := 'INCORRECT';
               err_msg := 'Section end milepoinit (end_section_mp) <> Element end milepoint (end_elemeent_mp)';
                 
               col_name1 := 'Route Number';
               col_val1 := previous_route_number;
               col_name2 := 'Element ID';
               col_val2 := TO_CHAR (previous_element_id);
               col_name3 := 'Section ID';
               col_val3 := TO_CHAR (rec.section_id);
               Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                        col_name3,
                        col_val3,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);
                  
            END IF;
            
            IF sum_section_length <> element_length 
            THEN
               err_msg := ' SUM Section Length ' || sum_section_length || ' <>  Element Length ' || element_length;
               tname := 'Section Length Test';
               assess := 'INCORRECT';
              
               col_name1 := 'Route Number';
               col_val1 := previous_route_number;
               col_name2 := 'Element ID';
               col_val2 := TO_CHAR (previous_element_id);
               
               Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                         NULL,
                         NULL,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);       
            
                
            END IF;
            
              element_length := rec.end_element_milepoint - rec.begin_element_milepoint;
              section_length := rec.end_section_mp - rec.begin_section_mp;
              sum_section_length :=  section_length;
            
            previous_begin_element_mp := rec.begin_element_milepoint;
            previous_end_element_mp  := rec.end_element_milepoint;
            previous_end_section_mp := rec.end_section_mp;
            previous_element_id := rec.element_id;
            previous_route_number := rec.route_number;
            previous_cmp := rec.cumulative_milepoint_order;
            
            
     END IF;  -- end of element
  ELSE -- we have a new route
         
        IF     previous_end_section_mp <> previous_end_element_mp
        THEN   
         tname := 'Gap in Route by Comparing Mileage';
               assess := 'INCORRECT';
               err_msg := 'Section end milepoint (end_section_mp) <> Element end milepoint (end_elemeent_mp)';
                 
               col_name1 := 'Route Number';
               col_val1 := previous_route_number;
               col_name2 := 'Element ID';
               col_val2 := TO_CHAR (previous_element_id);
               col_name3 := 'Section ID';
               col_val3 := TO_CHAR (rec.section_id);
               Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                        col_name3,
                        col_val3,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);
        END IF;   
                
        IF sum_section_length <> element_length 
        THEN
               err_msg := ' SUM Section Length ' || sum_section_length || ' <>  Element Length ' || element_length;
                err_msg := ' SUM Section Length ' || sum_section_length || ' <>  Element Length ' || element_length;
               tname := 'Section Length Test';
               assess := 'INCORRECT';
              
               col_name1 := 'Route Number';
               col_val1 := previous_route_number;
               col_name2 := 'Element ID';
               col_val2 := TO_CHAR (previous_element_id);
               
               Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                         NULL,
                         NULL,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);       
 
        END IF;
          
         
         IF rec.begin_element_milepoint <> 0
         THEN 
            IF rec.route_type <> 'T' -- rail routes may not begin at begin_section_mp 0
               THEN
                   tname := 'Route Starts at Begin Milepoint 0';
                   assess := 'INCORRECT';
                   err_msg := 'does not start at 0';
                   col_name1 := 'Route Number';
                   col_val1 := rec.route_number;
                   col_name2 := 'Element ID';
                   col_val2 := rec.element_id;
                   Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                         NULL,
                         NULL,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);
            END IF;
         END IF;
         
         IF rec.begin_section_mp <> 0
         THEN 
            IF rec.route_type <> 'T' -- rail routes may not begin at begin_section_mp 0
            THEN
               err_msg := ' Segment does not start at 0';
               tname := 'Route Starts at Begin Milepoint 0';
               assess := 'INCORRECT';
               err_msg := 'Section does not start at 0';
               col_name1 := 'Route Number';
               col_val1 := rec.route_number;
               col_name2 := 'Section ID';
               col_val2 := rec.section_id;
               Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                         NULL,
                         NULL,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);
            END IF;
         END IF;
 
         num_routes := num_routes + 1;
         num_elements :=  1;
         
         element_length := rec.end_element_milepoint - rec.begin_element_milepoint;
         section_length := rec.end_section_mp - rec.begin_section_mp;
         sum_section_length :=  section_length;
 
         previous_begin_element_mp := rec.begin_element_milepoint;
         previous_end_element_mp  := rec.end_element_milepoint;
         previous_end_section_mp := rec.end_section_mp;
         previous_element_id := rec.element_id;
         previous_route_number := rec.route_number;
                  
  END IF;
    
END LOOP;

-- Final checks

    IF     previous_end_section_mp <> previous_end_element_mp
    THEN   
         tname := 'Gap in Route by Comparing Mileage';
               assess := 'INCORRECT';
               err_msg := 'Section end milepoint (end_section_mp) <> Element end milepoint (end_elemeent_mp)';
                 
               col_name1 := 'Route Number';
               col_val1 := previous_route_number;
               col_name2 := 'Element ID';
               col_val2 := TO_CHAR (previous_element_id);
               col_name3 := 'Section ID';
               col_val3 := TO_CHAR (rec.section_id);
               Write_it (tab,
                         NULL,
                         NULL,
                         err_msg,
                         col_name1,
                         col_val1,
                         col_name2,
                         col_val2,
                        col_name3,
                        col_val3,
                         NULL,
                         NULL,
                         tname,
                         test_procedure,
                         rundate,
                         assess);
        END IF;            
    
CLOSE ar;

 SELECT COUNT (*)
        INTO cntr
        FROM data_exceptions
       WHERE table_name = 'route_sections';

      SELECT COUNT (*)
        INTO cntr_added
        FROM data_exceptions
       WHERE table_name = 'route_sections' AND test_date = rundate;


      WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
         OWNER         => 'WH_ASSETS',
         OBJECT_NAME   => 'DATA_EXCEPTIONS',
         object_cnt    => cntr,
         add_cnt       => cntr_added,
         proc          => $$PLSQL_UNIT,
         start_time    => start_time);
   EXCEPTION
      WHEN OTHERS
      THEN
         wh_common.pkg_common_utilities.update_whse_log (
            'WH_ASSETS',
            $$PLSQL_UNIT,
            NULL,
            NULL,
            NULL,
            NULL,
               'Error during '
            || $$PLSQL_UNIT
            || ' Line:'
            || $$PLSQL_LINE
            || ': '
            || SUBSTR (SQLERRM, 1, 400),
            'Failed');
         wh_common.pkg_common_utilities.exit_and_report (
            $$PLSQL_UNIT,
            'FAILURE',
               'Error during '
            || $$PLSQL_UNIT
            || ': '
            || SUBSTR (SQLERRM, 1, 400));
         RAISE_APPLICATION_ERROR (
            -20030,
            $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
   END;
END;
/
