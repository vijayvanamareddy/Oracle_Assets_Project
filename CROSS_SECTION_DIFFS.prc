CREATE OR REPLACE PROCEDURE cross_section_diffs
IS
   /**********************************************************************
   This procedure identifies diffs comparing the most recent cross_section record
   from the cross_section_history table with the one in cross_section_staging table.

   It is run as part of the cross_section_weekly_refresh 

   The results of the changes are put into the cross_section_change_table

   04-30-2019 SH - Initial Version
  
   **********************************************************************/
   cntr                     NUMBER := 0;
   g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
   g_jobname                VARCHAR2 (30) := $$PLSQL_UNIT;
   g_start_time             DATE := SYSDATE;
   g_object                 VARCHAR2 (30) := 'CROSS_SECTION_CHANGES';
   g_SQLMSG                 VARCHAR2 (1000) := NULL;
   V_flat_file_counts_txt   VARCHAR2 (1000) := NULL;

   retval                   BOOLEAN;
   commit_count             NUMBER := 0;
   table1                   VARCHAR2 (30) := 'CROSS_SECTION_HISTORY';  -- tables to compare
   table2                   VARCHAR2 (30) := 'CROSS_SECTION_STAGING';
   alias1                   VARCHAR2 (2) := 's'; -- aliases to differentiate column names
   alias2                   VARCHAR2 (2) := 'ss';
   join_column1             VARCHAR2 (30) := 'ELEMENT_ID'; -- columns to join comparison tables on
   join_column2             VARCHAR2 (30) := 'BEGIN_OFFSET'; -- columns to join comparison tables on
   join_column3             VARCHAR2 (30) := 'END_OFFSET'; -- columns to join comparison tables on
   join_column4             VARCHAR2 (30) := 'ROUTE_NUMBER';
   where_clause             VARCHAR2 (1000);
   prim_key                 VARCHAR2 (30) := 'SECTION_ID'; -- primary key to identify row changed

   TYPE change_rec IS RECORD
   (
      pkey         NUMBER,                 -- unique identifier of changed row
      element_id   cross_section_history.element_id%TYPE,                   -- natural keys
      begin_offset cross_section_history.begin_offset%TYPE,                   -- natural keys
      end_offset   cross_section_history.end_offset%TYPE,                   -- natural keys
      route_number cross_section_history.route_number%TYPE,
      string1      VARCHAR2 (500),                       -- columns to compare
      string2      VARCHAR2 (500)                        -- set to size of largest string in table
   );

   rec                      change_rec;

   CV                       SYS_REFCURSOR;

   CURSOR cols                  -- Gets the list of columns we want to compare
   IS
        SELECT column_name
          FROM user_tab_columns
         WHERE     table_name = table2
               AND column_name NOT IN ('ELEMENT_ID', 'SECTION_ID',  'BEGIN_OFFSET', 'END_OFFSET', 'ELEMENT_WID', 'ROUTE_NUMBER')
      ORDER BY column_name;


   PROCEDURE write_it (sect_id     IN NUMBER,
                       el_id      IN NUMBER,
                       boffset      IN NUMBER,
                       eoffset      IN NUMBER,
                       rte_num     IN VARCHAR2,
                       cdate       IN DATE,
                       col_name    IN VARCHAR2,
                       old_value   IN VARCHAR2,
                       new_value   IN VARCHAR2)
   IS
   BEGIN
      INSERT INTO cross_section_changes                          
                                        (section_id,
                                         element_id,
                                         begin_offset,
                                         end_offset,
                                         change_type,
                                         change_date,
                                         column_name,
                                         route_number,
                                         modified_by,
                                         old_value,
                                         new_value)
           VALUES (sect_id,
                   el_id,
                   boffset,
                   eoffset,
                   'U',
                   cdate,
                   col_name,
                   rte_num,
                   g_jobname,
                   SUBSTR (old_value, 1, 120),
                   SUBSTR (new_value, 1, 120));



      commit_count := commit_count + 1;
      cntr := cntr + 1;

      IF commit_count > 1000
      THEN
         COMMIT;
         commit_count := 0;
      END IF;
   END;                                                  -- procedure write_it
BEGIN
   BEGIN
      where_clause :=
            alias1
         || '.'
         || join_column1
         || '='
         || alias2
         || '.'
         || join_column1
         || ' AND '
         ||     alias1
         || '.'
         || join_column2
         || '='
         || alias2
         || '.'
         || join_column2
         || ' AND '
         ||     alias1
         || '.'
         || join_column3
         || '='
         || alias2
         || '.'
         || join_column3
           || ' AND '
         ||     alias1
         || '.'
         || join_column4
         || '='
         || alias2
         || '.'
         || join_column4
         || ' AND '
         ||   alias1
         || '.END_DATE IS NULL'
       ;


      -- Loop through the column names
      FOR c IN cols
      LOOP
      
      OPEN CV FOR
            'select '
         || alias1
         || '.'
         || prim_key
         || ','
         || alias1
         || '.'
         || join_column1
         || ','
         || alias1
         || '.'
         || join_column2
         || ','
          || alias1
         || '.'
         || join_column3
         || ','
         || alias1
         || '.'
         || join_column4
         || ','
         || alias1
         || '.'
         || c.column_name
         || ', '
         || alias2
         || '.'
         || c.column_name
         || ' from '
         || table1
         || ' '
         || alias1
         || ','
         || table2
         || ' '
         || alias2
         || ' WHERE '
         || where_clause;
     
            
 


         LOOP
            FETCH CV INTO rec;

 
            EXIT WHEN CV%NOTFOUND;


            RetVal :=
               wh_assets.compare (TO_CHAR (rec.string1),
                                  TO_CHAR (rec.string2));

            IF retval = FALSE
            THEN
               Write_it (rec.pkey,
                         rec.element_id,
                          rec.begin_offset,
                           rec.end_offset,
                           rec.route_number,
                         g_start_time,
                         c.column_name,
                         TO_CHAR (rec.string1),
                         TO_CHAR (rec.string2));
            END IF;
         END LOOP;

         CLOSE CV;
      END LOOP;

      COMMIT;

      SELECT COUNT (*) INTO cntr FROM cross_section_changes;

      WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
         OWNER         => G_OWNER,
         OBJECT_NAME   => g_object,
         object_cnt    => cntr,
         proc          => $$PLSQL_UNIT,
         start_time    => g_start_time);

      wh_common.pkg_common_utilities.EXIT_AND_REPORT (g_jobname,
                                                      'NORMAL',
                                                      V_flat_file_counts_txt);

   -- Failure outcome


   EXCEPTION
      WHEN OTHERS
      THEN
         G_SQLMSG := SUBSTR (SQLERRM, 1, 400);
         wh_common.pkg_common_utilities.update_whse_log (
            g_owner,
            g_object,
            NULL,
            NULL,
            NULL,
            NULL,
            'Error during ' || g_jobname || ': ' || G_SQLMSG,
            'Failed');
         wh_common.pkg_common_utilities.exit_and_report (
            g_jobname,
            'FAILURE',
            g_jobname || ' - ' || G_SQLMSG);
         RAISE_APPLICATION_ERROR (-20020, $$PLSQL_UNIT || ' ' || G_SQLMSG);
   END;
   END;
/
