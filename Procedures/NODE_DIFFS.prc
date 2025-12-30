CREATE OR REPLACE PROCEDURE node_diffs
IS
   /**********************************************************************
   This procedure identifies diffs comparing the most recent nodes record
   from the nodes_history table with the one in the nodes_staging table.

   It is run as part of the nodes_weekly_refresh which loads the nodes_staging_table

   The results of the changes are put into the nodes_changes table

   03-06-2019 SH - Initial Version
   03-25-19 SH - Move version in wh_assets_dev to test
   **********************************************************************/



   TYPE change_rec IS RECORD
   (
      pkey         NUMBER,                 -- unique identifier of changed row
      node_id   nodes_history.node_id%TYPE,                   -- natural keys
      string1      VARCHAR2 (120),                       -- columns to compare
      string2      VARCHAR2 (120)
   );

   rec            change_rec;

   CV             SYS_REFCURSOR;

   table1         VARCHAR2 (30) := 'NODES_HISTORY';            -- tables to compare
   table2         VARCHAR2 (30) := 'NODES_STAGING';
   alias1         VARCHAR2 (2) := 'h'; -- aliases to differentiate column names
   alias2         VARCHAR2 (2) := 'hs';
   join_column1   VARCHAR2 (30) := 'node_id'; -- columns to join comparison tables on

   expr           VARCHAR2 (1000);
   prim_key       VARCHAR2 (30) := 'node_id'; -- primary key to identify row changed


   CURSOR cols                  -- Gets the list of columns we want to compare
   IS
      SELECT column_name
        FROM user_tab_columns
       WHERE     table_name = table2
             AND column_name NOT IN ('NODE_ID', 'NODE_DESCRIPTION');


   RetVal         BOOLEAN;

   commit_count   NUMBER := 0;
   cntr_added     NUMBER := 0;
   cntr           NUMBER := 0;
   g_start_time   DATE := SYSDATE;
   g_owner        VARCHAR2 (20) := 'WH_ASSETS';
   g_jobname      VARCHAR2 (30) := 'NODE_DIFFS';
   g_object       VARCHAR2 (30) := 'NODE_CHANGES';
   g_sqlmsg       VARCHAR2 (500) := NULL;

   PROCEDURE write_it (
                       nodeid        IN NUMBER,
                       cdate         IN DATE,
                       column_name   IN VARCHAR2,
                       old_value     IN VARCHAR2,
                       new_value     IN VARCHAR2)
   IS
   BEGIN
      INSERT INTO node_changes                          -- log the update
                                        (
                                         node_id,
                                         change_type,
                                         change_date,
                                         column_name,
                                         table_name,
                                         modified_by,
                                         old_value,
                                         new_value)
           VALUES (
                   nodeid,
                   'U',
                   cdate,
                   column_name,
                   'NODES_HISTORY',
                   'NODE_DIFFS',
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

         RetVal := compare (to_char(rec.string1), to_char(rec.string2));

         IF retval = FALSE
         THEN
            Write_it (
                      rec.NODE_id,
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
