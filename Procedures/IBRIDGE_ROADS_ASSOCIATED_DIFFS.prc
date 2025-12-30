CREATE OR REPLACE PROCEDURE ibridge_roads_associated_diffs
IS
   /**********************************************************************
   This procedure identifies diffs in the roads associated with bridges by 
   comparing the most recent roads associated records 
   from the ibridge_roads_assoc_history table with the one in the ibridge_roads_assoc_staging table.

   It is run as part of the ibridge_roads_weekly_refresh

   The results of the changes are put into the Ibridges_changes, change log

   2-2015 SH - Initial Version
   6-30-2015 SH - Added primary_route_number and primary_route_name columns
   9-01-2015 SH - Use Compare Function to take Nulls into account
   9-30-2015 SH - Get column names from user_tab_columns, Add join on location_type and offset
   
   6-15-2016 SH - Modify for InspectTech Bridges, Rename to ibridge_roads_associated_diffs
   7-25-2016 SH -   Modify table name, ibridge_roads_assoc_history to ibrdg_roads_assoc_history to shorten it so it can be backed up
                   in weekly refresh cycle 
   9-11-2017 SH - Modified datatype of bridge_number from number to varchar2 in Write-it procedure so leading zeroes are retained   
   10-10-2017 SH - Modify expression to check for current record (end_date is null) to avoid reporting of false changes             
   **********************************************************************/

   TYPE change_rec IS RECORD
   (
      pkey            NUMBER,              -- unique identifier of changed row
      bridge_number   ibrdg_roads_assoc_history.bridge_number%TYPE,     -- natural keys
      element_id      ibrdg_roads_assoc_history.element_id%TYPE,
      string1         VARCHAR2 (120),                    -- columns to compare
      string2         VARCHAR2 (120)
   );

   rec            change_rec;

   CV             SYS_REFCURSOR;

   table1         VARCHAR2 (30) := 'IBRDG_ROADS_ASSOC_HISTORY';    -- tables to compare
   table2         VARCHAR2 (30) := 'IBRIDGE_ROADS_ASSOC_STAGING';
   alias1         VARCHAR2 (2) := 'r'; -- aliases to differentiate column names
   alias2         VARCHAR2 (2) := 'rs';
   join_column1   VARCHAR2 (30) := 'BRIDGE_NUMBER'; -- columns to join comparison tables on
   join_column2   VARCHAR2 (30) := 'ELEMENT_ID';
   join_column3   VARCHAR2 (30) := 'LOCATION_TYPE';
   join_column4   VARCHAR2 (30) := 'OFFSET';

   expr           VARCHAR2 (1000);
   prim_key       VARCHAR2 (30) := 'bridge_id'; -- primary key to identify row changed


   CURSOR cols                  -- Gets the list of columns we want to compare
   IS
      SELECT column_name
        FROM user_tab_columns
       WHERE table_name = table2;



   commit_count   NUMBER := 0;
   diff_count     NUMBER := 0;
   start_time     DATE := SYSDATE;
   RetVal         BOOLEAN;

   cntr           NUMBER;

   PROCEDURE write_it (brdg_id       IN NUMBER,
                       brdg_no       IN VARCHAR2,
                       cdate            DATE,
                       ele_id        IN NUMBER,
                       column_name   IN VARCHAR2,
                       old_value     IN VARCHAR2,
                       new_value     IN VARCHAR2)
   IS
   BEGIN
      INSERT INTO ibridges_changes (bridge_id,
                                        bridge_number,
                                        change_type,
                                        change_date,
                                        column_name,
                                        table_name,
                                        element_id_roads_assoc,
                                        modified_by,
                                        old_value,
                                        new_value)
           VALUES (brdg_id,
                   brdg_no,
                   'U',
                   cdate,
                   column_name,
                   'IBRDG_ROADS_ASSOC_HISTORY',
                   ele_id,
                   'IBRIDGE_ROADS_ASSOCIATED_DIFFS',
                   old_value,
                   new_value);


      diff_count := diff_count + 1;
      commit_count := commit_count + 1;


      IF commit_count > 1000
      THEN
         COMMIT;
         commit_count := 0;
      END IF;
   END;                                                  -- procedure write_it
BEGIN
   -- Build up the where clause
   expr :=
         alias1
      || '.'
      || join_column1
      || '='
      || alias2
      || '.'
      || join_column1
      || ' AND '
      || alias1
      || '.'
      || join_column2
      || ' = '
      || alias2
      || '.'
      || join_column2
      || ' AND '
      || alias1
      || '.'
      || join_column3
      || ' = '
      || alias2
      || '.'
      || join_column3
      || ' AND '
      || alias1
      || '.'
      || join_column4
      || ' = '
      || alias2
      || '.'
      || join_column4 
      || ' and end_date is null';

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

         RetVal :=
            wh_assets.compare (TO_CHAR (rec.string1), TO_CHAR (rec.string2));

         IF retval = FALSE
         THEN
            Write_it (rec.pkey,
                      rec.bridge_number,
                      start_time,
                      rec.element_id,
                      c.column_name,
                      TO_CHAR (rec.string1),
                      TO_CHAR (rec.string2));
         END IF;
      END LOOP;

      CLOSE CV;
   END LOOP;

   COMMIT;


      SELECT COUNT (*) INTO cntr FROM ibridges_changes;

      WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
         OWNER         => 'WH_ASSETS',
         OBJECT_NAME   => 'IBRIDGES_CHANGES',
         object_cnt    => cntr,
         add_cnt       => diff_count,
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
   END;
/
