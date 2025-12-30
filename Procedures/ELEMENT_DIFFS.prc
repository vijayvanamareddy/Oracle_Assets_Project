CREATE OR REPLACE PROCEDURE element_diffs
IS
   /**********************************************************************
   This procedure identifies diffs comparing the most recent element record
   from the element_history table with the one in element_staging table.

   It is run as part of the element_weekly_refresh which loads the element_staging_table

   The results of the changes are put into the element_change_table

   3-17-2015 SH - Initial Version
   8-31-2015 SH - Use Compare Function to account for nulls
   9-28-2015 SH - Modify to get comparison columns from user_tab_columns
   9-29-2015 SH - Drop unused columns from staging table
   3-20-2018 SH - Add ferry and rail routes, rename procedure from highway_diffs to element_diffs
   7-31-2018  SH - Rename highway_id to element_wid (element warehouse_id) as the network contains more than highways 
   **********************************************************************/



   TYPE change_rec IS RECORD
   (
      pkey         NUMBER,                 -- unique identifier of changed row
      element_id   element_history.element_id%TYPE,                   -- natural keys
      string1      VARCHAR2 (120),                       -- columns to compare
      string2      VARCHAR2 (120)
   );

   rec            change_rec;

   CV             SYS_REFCURSOR;

   table1         VARCHAR2 (30) := 'ELEMENT_HISTORY';            -- tables to compare
   table2         VARCHAR2 (30) := 'ELEMENT_STAGING';
   alias1         VARCHAR2 (2) := 'h'; -- aliases to differentiate column names
   alias2         VARCHAR2 (2) := 'hs';
   join_column1   VARCHAR2 (30) := 'element_id'; -- columns to join comparison tables on

   expr           VARCHAR2 (1000);
   prim_key       VARCHAR2 (30) := 'element_wid'; -- primary key to identify row changed


   CURSOR cols                  -- Gets the list of columns we want to compare
   IS
      SELECT column_name
        FROM user_tab_columns
       WHERE     table_name = table2
             AND column_name NOT IN ('ELEMENT_ID', 'ELEMENT_WID');


   RetVal         BOOLEAN;

   commit_count   NUMBER := 0;
   cntr_added     NUMBER := 0;
   cntr           NUMBER := 0;
   g_start_time   DATE := SYSDATE;
   g_owner        VARCHAR2 (20) := 'WH_ASSETS';
   g_jobname      VARCHAR2 (30) := 'DIFFS';
   g_object       VARCHAR2 (30) := 'ELEMENT_CHANGE_TABLE';
   g_sqlmsg       VARCHAR2 (500) := NULL;

   PROCEDURE write_it (ele_wid        IN NUMBER,
                       ele_id        IN NUMBER,
                       cdate         IN DATE,
                       column_name   IN VARCHAR2,
                       old_value     IN VARCHAR2,
                       new_value     IN VARCHAR2)
   IS
   BEGIN
      INSERT INTO element_change_table                          -- log insert
                                        (element_wid,
                                         element_id,
                                         change_type,
                                         change_date,
                                         column_name,
                                         table_name,
                                         modified_by,
                                         old_value,
                                         new_value)
           VALUES (ele_wid,
                   ele_id,
                   'U',
                   cdate,
                   column_name,
                   'ELEMENT_HISTORY',
                   'ELEMENT_DIFFS',
                   old_value,
                   new_value);

      cntr_added := cntr_added + 1;
      commit_count := commit_count + 1;


      IF commit_count > 1000
      THEN
         COMMIT;
         commit_count := 0;
      END IF;
   END;                                                  -- procedure write_it
BEGIN
   expr :=
      alias1 || '.' || join_column1 || '=' || alias2 || '.' || join_column1 || ' AND END_DATE IS NULL';


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
         || expr;

      LOOP
         FETCH CV INTO rec;

         EXIT WHEN CV%NOTFOUND;

         RetVal := wh_assets.compare (to_char(rec.string1), to_char(rec.string2));

         IF retval = FALSE
         THEN
            Write_it (rec.pkey,
                      rec.element_id,
                      g_start_time,
                      c.column_name,
                      to_char(rec.string1),
                      to_char(rec.string2));
            END IF;

      END LOOP;

      CLOSE CV;
   END LOOP;

   COMMIT;


   SELECT COUNT (*) INTO cntr FROM element_change_table;

   WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
      OWNER         => G_OWNER,
      OBJECT_NAME   => g_object,
      object_cnt    => cntr,
      add_cnt       => cntr_added,
      proc          => $$PLSQL_UNIT,
      start_time    => g_start_time);
EXCEPTION
   WHEN OTHERS
   THEN
      G_SQLMSG := $$PLSQL_UNIT || ': ' || SUBSTR (SQLERRM, 1, 400);
      WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
         OWNER         => G_OWNER,
         OBJECT_NAME   => g_object,
         MSG           => G_SQLMSG,
         STATUS        => 'Failed');

      WH_COMMON.PKG_COMMON_UTILITIES.EXIT_AND_REPORT (
         g_jobname,
         'FAILURE',
         $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
END;
/
