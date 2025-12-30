CREATE OR REPLACE PROCEDURE ibridge_diffs
IS
   /**********************************************************************
   This procedure identifies diffs comparing the most recent bridge record
   from the ibridges_history table with the one in ibridges_staging table.

   It is run as part of the ibridges_weekly_refresh which loads the bridges_staging_table

   The results of the changes are put into the ibridges_changes table.

   2-2015 SH - Initial Version
   9-1-2015 SH - Use Compare Function to account for nulls
   9-15-2015 SH - Add column route_type_on_structure
   9-30-2015 SH - Get columns from user_tab_columns
   
   6-14-2016 SH - Modify for Inspect Tech bridges
   11-21-2016 SH - Fix error where overwriting expr, losing 'Where end_date is null'
   12-07-16 SH - split into ibridges_daily_refresh and ibridges_weekend_refresh
                  Remove comparison of columns from metrans which are only updated on the weekend:
                  - Element_id_on_structure,  section_id,  begin_section_offset, end_section_offset, route_type_on_structure, Highway_id_on_structure, 
                     primary_route_number, primary_route_name, priority
   12-09-16 SH Remove comparison of town related columns which can only be ordered on the weekend since they are based on the route  
   02-17-17 SH - Add the metrans offset back in.  Needed to calculate the location of the bridge on primary/alternate routes - Ed Beckwith request
                 New column named milepoint will refer to the milepoint on the primary route and come from InspectTech
                 offset will refer to the offset of the bridge on the element and come from METrans.  
                 In this procedure add column 'OFFSET' to list of columns only compared on the weekend
   09-01-17 SH Remove comparison of asset_type which changes from highway_bridge to rail_bridge for those that are both 
   09-05-17 SH Change Sunday to a weekday for columns to compare      
   09-11-17 SH Stop comparing location related columns as they are compared in roads_associated_diffs.  Getting false diffs    
   06-10-20 SH Stop comparing MTRNS_ASSETNO which only changes on the weekend   
   **********************************************************************/

   TYPE change_rec IS RECORD
   (
      pkey            NUMBER,              -- unique identifier of changed row
      bridge_number   ibridges_history.bridge_number%TYPE,              -- natural keys
      string1         VARCHAR2 (120),                    -- columns to compare
      string2         VARCHAR2 (120)
   );

   rec            change_rec;
   CV             SYS_REFCURSOR;

   table1         VARCHAR2 (30) := 'IBRIDGES_HISTORY';             -- tables to compare
   table2         VARCHAR2 (30) := 'IBRIDGES_STAGING';
   alias1         VARCHAR2 (2) := 'b'; -- aliases to differentiate column names
   alias2         VARCHAR2 (2) := 'bs';
   join_column1   VARCHAR2 (30) := 'bridge_number'; -- columns to join comparison tables on

   expr           VARCHAR2 (1000);
   prim_key       VARCHAR2 (30) := 'bridge_id'; -- primary key to identify row changed
day_of_week              VARCHAR2 (3);


 

   CURSOR cols                  -- Gets the list of columns we want to compare
   IS
      SELECT column_name
        FROM user_tab_columns
       WHERE     table_name = table2
       AND column_name NOT IN ('BEGIN_SECTION_OFFSET','BRIDGE_ID', 'BRIDGE_NUMBER','ELEMENT_ID_ON_STRUCTURE','END_SECTION_OFFSET',
             'HIGHWAY_ID_ON_STRUCTURE','OFFSET','PRIMARY_ROUTE_NAME','PRIMARY_ROUTE_NUMBER','PRIORITY', 'ROUTE_TYPE_ON_STRUCTURE','SECTION_ID','TOWNCODE', 'TOWNCODE2', 'TOWN_NAME1', 'TOWN_NAME2', 
             'PLACECODE', 'PLACECODE_DESCR', 'COUNTY','COUNTY_NAME', 'COUNTY2', 'COUNTY2_NAME','ASSET_TYPE', 'MTRNS_ASSETNO');


   commit_count   NUMBER := 0;
   diff_count     NUMBER := 0;
   cntr           NUMBER := 0;
   start_time     DATE := SYSDATE;

   RetVal         BOOLEAN;


   PROCEDURE write_it (brdg_id       IN NUMBER,
                       brdg_num      IN VARCHAR2,
                       cdate         IN DATE,
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
                                        modified_by,
                                        table_name,
                                        old_value,
                                        new_value)
           VALUES (brdg_id,
                   brdg_num,
                   'U',
                   cdate,
                   column_name,
                   'IBRIDGE_DIFFS',
                   'IBRIDGES',
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
   BEGIN
     SELECT TO_CHAR (SYSDATE, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') INTO day_of_week FROM DUAL;
      expr :=
            alias1
         || '.'
         || join_column1
         || '='
         || alias2
         || '.'
         || join_column1
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
               wh_assets.compare (TO_CHAR (rec.string1),
                                  TO_CHAR (rec.string2));

            IF retval = FALSE
            THEN
               Write_it (rec.pkey,
                         rec.bridge_number,
                         start_time,
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
END;
/
