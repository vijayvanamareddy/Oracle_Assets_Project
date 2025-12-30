CREATE OR REPLACE PROCEDURE test_mileage
IS
/**********************************************************************
This procedure tests various conditions

07-09-2015 SH - Initial Version

- Compares Total Miles for all highways in the highways table with the total miles in the sections table, 
  with the tide segment table, and with Metrans. The highways miles will only match sections miles when 
  tide load schema = tide1
08-11-2015 SH - Write results to data_exceptions table
09-21-2015 SH - Add standard error handling procedures
08-01-2016 SH - Modify to use TIG sections
08-15-2016 SH - Use only elements where existing = 'Y' (eliminate proposed elements) in comparison
09-12-2016 SH - Elminate tide comparisons, log route number where mileage doesn't match between highways and roadway_sections 
03-07-2017 SH - Add test for null lane_position to aid in finding problem with gap in metrans lane data
11-28-2018 SH - Modify  references to roadway_sections view to roadway_sections_history table where end_date is null 
                  and highways view to use highways_history table where end_date is null in preparation for going to full network
02-12-2019 SH - Modify to use full network and geoprocessing segmentation.
                Rename procedure to test_mileage   
03-27-2019 SH - Move from dev to test                              
**********************************************************************/

BEGIN
   DECLARE
      element_miles       NUMBER := 0;
      section_miles        NUMBER := 0;
      metrans_miles        NUMBER := 0;
      err_msg              VARCHAR2 (100);
      tab                  VARCHAR2 (30) := 'ELEMENT_HISTORY';
      test_procedure       VARCHAR2 (30) := 'TEST_MILEAGE';
      rundate              DATE := SYSDATE;
      col_name1            VARCHAR2 (30);
      col_val1             VARCHAR2 (30);
      col_name2            VARCHAR2 (30);
      col_val2             VARCHAR2 (30);
      col_name3            VARCHAR2 (30);
      col_val3             VARCHAR2 (30);
      col_name4            VARCHAR2 (30);
      col_val4             VARCHAR2 (30);
      tname                VARCHAR2 (100);
      assess               VARCHAR2 (10);
      asset_id_col         VARCHAR2 (30);
      asset_id_val         NUMBER;

      cntr                 NUMBER := 0;
      cntr_added           NUMBER := 0;
      start_time           DATE := SYSDATE;
      bad_lanes            NUMBER := 0;
      
    CURSOR rtes IS  
    SELECT primary_route_number, SUM (element_Length) as smiles FROM element_history h WHERE existing = 'Y' AND h.end_date is null group by primary_route_number 
    MINUS
    SELECT route_number, SUM (section_length)  FROM route_sections s where s.primary = 'Y' AND s.existing = 'Y'
    GROUP BY route_number;

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
    
        
      SELECT SUM (end_offset - begin_offset) INTO section_miles FROM sections_history s 
      JOIN element_history h ON s.element_id = h.element_id WHERE existing = 'Y' AND h.end_date is null AND s.end_date IS NULL;

      SELECT SUM (element_Length) INTO element_miles FROM element_history h WHERE existing = 'Y' AND h.end_date is null;

      SELECT SUM (ee.ne_length)
        INTO metrans_miles -- need to compare metrans miles after refresh and before changes for week entered
        FROM nm_elements@metrans e,
             nm_members@metrans m,
             nm_elements_all@metrans ee,
             v_bns_prirte@metrans p
       WHERE     e.ne_id = m.nm_ne_id_in
             AND m.nm_ne_id_of = ee.ne_id
             AND ee.ne_end_date IS NULL
             AND e.ne_gty_group_type IN ('RINV',
                                         'RNMU',
                                         'RNMI',
                                         'RNMS',
                                         'RMPM',
                                         'RMPL',
                                         'RCOL',
                                         'RFER',
                                         'RTRL',
                                         'RRRT')
             AND  ee.ne_length > 0               -- eliminate distance breaks                                            
             AND  ee.ne_name_2 = 'Y'             -- Exissting elements only (not proposed)
             AND  ee.ne_id = p.ne_id             -- primary route onlY
             AND  e.ne_descr = p.rtname;         -- primary route only

      -- Test Sum of Element Miles Matches Source
      tname := 'Sum of Element Miles Matches Source';
      assess := 'INCOMPLETE';                      -- if they are not the same

      IF element_miles<> metrans_miles
      THEN
         err_msg := 'Sum of Element Miles Does not Match Sum of METRANS miles';
         col_name1 := 'Assets Miles';
         col_name2 := 'METRANS Miles';
         col_val1 := TO_CHAR (element_miles);
         col_val2 := TO_CHAR (metrans_miles);
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

          -- Test Sum of Section Miles Matches Sum of Element Miles
            tname := 'Sum of Section Miles Matches Sum of Element Miles';

            IF section_miles <> element_miles
            THEN
               err_msg :=
                  'Sum of Section Miles Does not Match Sum of element miles';
               col_name1 := 'Assets Section Miles';
               col_name2 := 'Assets Element Miles';
               col_val1 := TO_CHAR (section_miles);
               col_val2 := TO_CHAR (element_miles);
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
          

            -- Log routes where Sum of Section Miles Does not match Sum of Highway Miles
            tname := 'Sum of Route Section Miles Matches Sum of Element Miles';
            FOR r in rtes LOOP
               err_msg :=
                  'Sum of Section Miles Does not Match Sum of element miles';
               col_name1 := 'Route_Number';
               col_name2 := 'Assets Section Miles';
               col_val1 := r.primary_route_number;
               col_val2 := TO_CHAR (r.smiles);
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
                        
            END LOOP;
       END IF;

      COMMIT;
      
      
     SELECT COUNT (*)
     INTO cntr
     FROM data_exceptions
    WHERE table_name = 'ELEMENT_HISTORY' ;

   SELECT COUNT (*)
     INTO cntr_added
     FROM data_exceptions
    WHERE table_name = 'ELEMENT_HISTORY' AND test_date = rundate;


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
         'Error during ' || $$PLSQL_UNIT || ': ' || SUBSTR (SQLERRM, 1, 400));
      RAISE_APPLICATION_ERROR (
         -20010,
         $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
END;
 
END;
/
