CREATE OR REPLACE PROCEDURE ibridge_roads_weekly_refresh (
   cntr_threshold           IN NUMBER := 5000,
   staging_already_loaded   IN VARCHAR2 := 'N')
IS
   /********************************************************************************
   This procedure loads the roads_associated_staging table (ibridge_roads_assoc_staging) & compares it to the
   roads_associated table (ibrdg_roads_assoc_history) for the weekly refresh of roads associated with BRIDGES.
   Roads associated with a bridge can be over or under the bridge.
   New roads_associated are added.  Old roads_associated are 'RETIRED'.

   Changed characteristics of roads_associated cause the
   current roads_associated row to be updated with the new values.

   04-30-15  SH - Initial version

   05-07-2015 SH - Added check to ensure segment_id is the same also to handle the
   case where  multiple segments of the same element are associated with the bridge
   (ie bridge 5900)

   05-28-2015 SH - Add check to ensure offset is the same also to handle case where multiple
   offsets of the same segment are associated with the bridge (ie bridge 5933). Remove check
   for segment_id.
   Note bridge 5933 has the same element under it with different offsets in v_nm_brpt_nw view in metrans 10/1/15

   06-08-2015 SH - Add check of location_type when retiring a road associated with a bridge

   06-29-2015 SH - Add primary route number and primary route name columns to roads_associated_history

   09-10-2015 SH -  Add check of location_type when adding a road associated with a bridge

   10-01-2015 SH - Add check of location_type when updating a road associated with a bridge

   10-15-2015 SH - Run procedure load_bridge_roads_under to create table of roads under a bridge, roads_under_temporary,
   which roads_under_bridge view is based on

   06-14-2016 SH - Modify to create ibridge_roads_weekly_refresh for Inspect Tech Bridges and roadway_sections table

   07-25-2016 SH - Clean up logging, error handling, fix problem where we are not getting snapshot year
                   Modify table name, ibridge_roads_assoc_history to ibrdg_roads_assoc_history to shorten it so it can be backed up
                   in weekly refresh cycle
   08-06-2016 SH - Shorten procedure name in g_jobname for logging modified_by
   09-15-2016 SH - add nbi columns from inspectTech for inventory route under the bridge, named INVRTE_
   04-25-2017 SH  - Log errors written by Oracle to error log in data exceptions table rather than aborting refresh process
                    Log procedure & function when other exceptions in data exceptions table
    11-26-2019 SH - Add column MTRNS_ASSETNO  (bridge pointer) to provide the relationship for the underclearance height restrictions from InspectTech)                
   ************************************************************************************/
   CURSOR road_changes
   IS
      SELECT begin_section_offset,
             bridge_number,
             element_id,
             end_section_offset,
             highway_id,
             invrte_adt,
             invrte_adt_truck_percent,
             invrte_adt_yr,
             invrte_detour_length,
             invrte_dirsuffix,
             invrte_dirsuffix_descr,
             invrte_functionclass,
             invrte_functionclass_descr,
             invrte_horiz_clear,
             invrte_level_of_serv,
             invrte_level_of_serv_descr,
             invrte_lrs_rtenum,
             invrte_lrs_subrtenum,
             invrte_milepoint,
             invrte_min_vert_clear,
             invrte_on_base_hwynet,
             invrte_on_base_hwynet_descr,
             invrte_on_nhs,
             invrte_on_nhs_descr,
             invrte_on_strahnet,
             invrte_on_strahnet_descr,
             invrte_on_trucknet,
             invrte_on_trucknet_descr,
             invrte_rectype,
             invrte_rtenum,
             invrte_signprefix,
             invrte_signprefix_descr,
             invrte_toll,
             invrte_toll_descr,
             invrte_traffic_dir,
             invrte_traffic_dir_descr,
             location_level,
             location_type,
             mtrns_assetno,
             offset,
             primary_route_name,
             primary_route_number,
             section_id
        FROM ibridge_roads_assoc_staging
      MINUS
      SELECT begin_section_offset,
             bridge_number,
             element_id,
             end_section_offset,
             highway_id,
             invrte_adt,
             invrte_adt_truck_percent,
             invrte_adt_yr,
             invrte_detour_length,
             invrte_dirsuffix,
             invrte_dirsuffix_descr,
             invrte_functionclass,
             invrte_functionclass_descr,
             invrte_horiz_clear,
             invrte_level_of_serv,
             invrte_level_of_serv_descr,
             invrte_lrs_rtenum,
             invrte_lrs_subrtenum,
             invrte_milepoint,
             invrte_min_vert_clear,
             invrte_on_base_hwynet,
             invrte_on_base_hwynet_descr,
             invrte_on_nhs,
             invrte_on_nhs_descr,
             invrte_on_strahnet,
             invrte_on_strahnet_descr,
             invrte_on_trucknet,
             invrte_on_trucknet_descr,
             invrte_rectype,
             invrte_rtenum,
             invrte_signprefix,
             invrte_signprefix_descr,
             invrte_toll,
             invrte_toll_descr,
             invrte_traffic_dir,
             invrte_traffic_dir_descr,
             location_level,
             location_type,
             mtrns_assetno,
             offset,
             primary_route_name,
             primary_route_number,
             section_id
        FROM ibrdg_roads_assoc_history
       WHERE end_date IS NULL;

   rec                      road_changes%ROWTYPE;

   CURSOR retired_roads
   IS                              -- roads no longer associated with a bridge
      SELECT bridge_number,
             element_id,
             offset,
             location_type
        FROM ibrdg_roads_assoc_history
       WHERE end_date IS NULL
      MINUS
      SELECT bridge_number,
             element_id,
             offset,
             location_type
        FROM ibridge_roads_assoc_staging;

   cntr_retired             NUMBER (5) := 0;
   cntr                     NUMBER (5) := 0;
   threshold_message        VARCHAR2 (200) := NULL;
   err_log_message          VARCHAR2 (200) := NULL;
   cntr_updated             NUMBER (5) := 0;
   cntr_added               NUMBER (5) := 0;
   g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
   g_jobname                VARCHAR2 (30) := 'ibridge_rds_wkly_refresh';
   g_object                 VARCHAR2 (30) := 'ibrdg_roads_assoc_history';
   V_flat_file_counts_txt   VARCHAR2 (1000) := NULL;
   start_time               DATE := SYSDATE;
   current_year             NUMBER;
   surrogate_key            NUMBER;
   errlog_count             NUMBER := 0;
   common_run_date          DATE := SYSDATE;

   FUNCTION get_bridge_id (brdg_num IN NUMBER)
      RETURN NUMBER
   IS
      brdg_id   NUMBER;
      err       VARCHAR2(100);
   BEGIN
      SELECT DISTINCT b.bridge_id
        INTO brdg_id
        FROM ibridges_history b
       WHERE b.bridge_number = brdg_num AND b.end_date IS NULL;

      RETURN brdg_id;
   EXCEPTION
      WHEN NO_DATA_FOUND -- road associated with a bridge not in bridges_history
      THEN
         RETURN NULL;
      WHEN OTHERS
      THEN
      err := 'Error num :'||to_char(sqlcode)||' '||substr(sqlerrm,1,70);
      INSERT INTO data_exceptions (TABLE_NAME,                                
                                      ERROR_CONDITION,                                     
                                      TEST_PROCEDURE,
                                      TEST_DATE,
                                      ASSESSMENT,
                                     COLUMN_NAME1,
                                     COLUMN_VALUE1,
                                     COLUMN_NAME2,
                                     COLUMN_VALUE2)
                      VALUES ('ibridges_history',
                              err,
                              g_jobname,
                              start_time,
                              'EXCEPTION',
                              'FUNCTION',
                              'GET_BRIDGE_ID',
                              'BRIDGE_NUMBER',
                              brdg_num);  
         RETURN NULL;
  
   END;
BEGIN
   SELECT MAX (snapshot_year)
     INTO current_year
     FROM ibrdg_roads_assoc_history;

   IF staging_already_loaded = 'N'
   THEN
      load_ibridge_staging_roads;
   END IF;

   FOR rec IN road_changes
   LOOP
      cntr := cntr + 1;
   END LOOP;

   IF cntr < cntr_threshold
   THEN
      ibridge_roads_associated_diffs;                 -- log diffs for updates

      EXECUTE IMMEDIATE 'TRUNCATE TABLE Ibridge_roads_assoc_error_log';

      FOR rec IN road_changes
      LOOP
         SELECT COUNT (*)
           INTO cntr
           FROM ibrdg_roads_assoc_history
          WHERE     bridge_number = rec.bridge_number
                AND element_id = rec.element_id
                AND offset = rec.offset
                AND location_type = rec.location_type
                AND end_date IS NULL;

         IF cntr > 0
         THEN                                      -- update the existing road
            BEGIN
               UPDATE ibrdg_roads_assoc_history
                  SET date_modified = start_time,
                      modified_by = g_jobname,
                      begin_section_offset = rec.begin_section_offset,
                      end_section_offset = rec.end_section_offset,
                      highway_id = rec.highway_id,
                      invrte_adt = rec.invrte_adt,
                      invrte_adt_truck_percent = rec.invrte_adt_truck_percent,
                      invrte_adt_yr = rec.invrte_adt_yr,
                      invrte_detour_length = rec.invrte_detour_length,
                      invrte_dirsuffix = rec.invrte_dirsuffix,
                      invrte_dirsuffix_descr = rec.invrte_dirsuffix_descr,
                      invrte_functionclass = rec.invrte_functionclass,
                      invrte_functionclass_descr =
                         rec.invrte_functionclass_descr,
                      invrte_horiz_clear = rec.invrte_horiz_clear,
                      invrte_level_of_serv = rec.invrte_level_of_serv,
                      invrte_level_of_serv_descr =
                         rec.invrte_level_of_serv_descr,
                      invrte_lrs_rtenum = rec.invrte_lrs_rtenum,
                      invrte_lrs_subrtenum = rec.invrte_lrs_subrtenum,
                      invrte_milepoint = rec.invrte_milepoint,
                      invrte_min_vert_clear = rec.invrte_min_vert_clear,
                      invrte_on_base_hwynet = rec.invrte_on_base_hwynet,
                      invrte_on_base_hwynet_descr =
                         rec.invrte_on_base_hwynet_descr,
                      invrte_on_nhs = rec.invrte_on_nhs,
                      invrte_on_nhs_descr = rec.invrte_on_nhs_descr,
                      invrte_on_strahnet = rec.invrte_on_strahnet,
                      invrte_on_strahnet_descr = rec.invrte_on_strahnet_descr,
                      invrte_on_trucknet = rec.invrte_on_trucknet,
                      invrte_on_trucknet_descr = rec.invrte_on_trucknet_descr,
                      invrte_rectype = rec.invrte_rectype,
                      invrte_rtenum = rec.invrte_rtenum,
                      invrte_signprefix = rec.invrte_signprefix,
                      invrte_signprefix_descr = rec.invrte_signprefix_descr,
                      invrte_toll = rec.invrte_toll,
                      invrte_toll_descr = rec.invrte_toll_descr,
                      invrte_traffic_dir = rec.invrte_traffic_dir,
                      invrte_traffic_dir_descr = rec.invrte_traffic_dir_descr,
                      location_level = rec.location_level,
                      mtrns_assetno = rec.mtrns_assetno,
                      primary_route_number = rec.primary_route_number,
                      primary_route_name = rec.primary_route_name,
                      section_id = rec.section_id
                WHERE     bridge_number = rec.bridge_number
                      AND element_id = rec.element_id
                      AND offset = rec.offset
                      AND location_type = rec.location_type   -- added 10/1/15
                      AND end_date IS NULL
                  LOG ERRORS INTO Ibridge_roads_assoc_error_log
                         ('Weekly Refresh - update existing road ' || SYSDATE)
                         REJECT LIMIT 100;

               cntr_updated := cntr_updated + 1;
            END;
         ELSE                  -- insert a new road associated with the bridge
            BEGIN
               cntr_added := cntr_added + 1;
               surrogate_key := get_bridge_id (rec.bridge_number); -- get the bridge_id of the current version of the bridge

               INSERT
                 INTO ibrdg_roads_assoc_history (begin_section_offset,
                                                 bridge_id,
                                                 bridge_number,
                                                 created_by,
                                                 date_created,
                                                 date_modified,
                                                 element_id,
                                                 end_date,
                                                 end_section_offset,
                                                 highway_id,
                                                 invrte_adt,
                                                 invrte_adt_truck_percent,
                                                 invrte_adt_yr,
                                                 invrte_detour_length,
                                                 invrte_dirsuffix,
                                                 invrte_dirsuffix_descr,
                                                 invrte_functionclass,
                                                 invrte_functionclass_descr,
                                                 invrte_horiz_clear,
                                                 invrte_level_of_serv,
                                                 invrte_level_of_serv_descr,
                                                 invrte_lrs_rtenum,
                                                 invrte_lrs_subrtenum,
                                                 invrte_milepoint,
                                                 invrte_min_vert_clear,
                                                 invrte_on_base_hwynet,
                                                 invrte_on_base_hwynet_descr,
                                                 invrte_on_nhs,
                                                 invrte_on_nhs_descr,
                                                 invrte_on_strahnet,
                                                 invrte_on_strahnet_descr,
                                                 invrte_on_trucknet,
                                                 invrte_on_trucknet_descr,
                                                 invrte_rectype,
                                                 invrte_rtenum,
                                                 invrte_signprefix,
                                                 invrte_signprefix_descr,
                                                 invrte_toll,
                                                 invrte_toll_descr,
                                                 invrte_traffic_dir,
                                                 invrte_traffic_dir_descr,
                                                 location_level,
                                                 location_type,
                                                 mtrns_assetno,
                                                 modified_by,
                                                 offset,
                                                 primary_route_name,
                                                 primary_route_number,
                                                 section_id,
                                                 snapshot_year,
                                                 start_date,
                                                 state)
                  VALUES (rec.begin_section_offset,
                          surrogate_key,                          -- BRIDGE_ID
                          rec.bridge_number,
                          g_jobname,                             -- CREATED_BY
                          start_time,                          -- date_created
                          NULL,                               -- date_modified
                          rec.element_id,
                          NULL,                                   --  END_DATE
                          rec.end_section_offset,
                          rec.highway_id,
                          rec.invrte_adt,
                          rec.invrte_adt_truck_percent,
                          rec.invrte_adt_yr,
                          rec.invrte_detour_length,
                          rec.invrte_dirsuffix,
                          rec.invrte_dirsuffix_descr,
                          rec.invrte_functionclass,
                          rec.invrte_functionclass_descr,
                          rec.invrte_horiz_clear,
                          rec.invrte_level_of_serv,
                          rec.invrte_level_of_serv_descr,
                          rec.invrte_lrs_rtenum,
                          rec.invrte_lrs_subrtenum,
                          rec.invrte_milepoint,
                          rec.invrte_min_vert_clear,
                          rec.invrte_on_base_hwynet,
                          rec.invrte_on_base_hwynet_descr,
                          rec.invrte_on_nhs,
                          rec.invrte_on_nhs_descr,
                          rec.invrte_on_strahnet,
                          rec.invrte_on_strahnet_descr,
                          rec.invrte_on_trucknet,
                          rec.invrte_on_trucknet_descr,
                          rec.invrte_rectype,
                          rec.invrte_rtenum,
                          rec.invrte_signprefix,
                          rec.invrte_signprefix_descr,
                          rec.invrte_toll,
                          rec.invrte_toll_descr,
                          rec.invrte_traffic_dir,
                          rec.invrte_traffic_dir_descr,
                          rec.location_level,
                          rec.location_type,
                          rec.mtrns_assetno,
                          NULL,                                --  MODIFIED_BY
                          rec.offset,
                          rec.primary_route_name,
                          rec.primary_route_number,
                          rec.section_id,
                          current_year,                       -- SNAPSHOT_YEAR
                          start_time,                           -- start_date,
                          'CURRENT')                                --  state,
                  LOG ERRORS INTO Ibridge_roads_assoc_error_log
                         ('Weekly Refresh - Insert new road ' || SYSDATE)
                         REJECT LIMIT 100;

               INSERT INTO ibridges_changes                      -- log insert
                                            (bridge_id,
                                             bridge_number,
                                             change_type,
                                             change_date,
                                             modified_by,
                                             table_name,
                                             element_id_roads_assoc)
                    VALUES (surrogate_key,
                            rec.bridge_number,
                            'I',
                            common_run_date,
                            g_jobname,
                            'ibrdg_roads_assoc_history',
                            rec.element_id);
            END;             -- insert a new road associated with the bridge ;
         END IF;                                                  -- cntr > 0;
      END LOOP;                                    -- for rec in road_changes;


      COMMIT;

      FOR rec IN retired_roads
      LOOP -- Bridges that had a road associated with it that is no longer associated
         UPDATE ibrdg_roads_assoc_history
            SET end_date = start_time,
                date_modified = start_time,
                state = 'RETIRED'
          WHERE     bridge_number = rec.bridge_number
                AND element_id = rec.element_id
                AND offset = rec.offset
                AND end_date IS NULL
            LOG ERRORS INTO Ibridge_roads_assoc_error_log
                   ('Weekly Refresh Delete retired roads - ' || SYSDATE)
                   REJECT LIMIT 100;

         surrogate_key := get_bridge_id (rec.bridge_number);


         INSERT INTO ibridges_changes                            -- log delete
                                      (bridge_id,
                                       bridge_number,
                                       change_type,
                                       change_date,
                                       modified_by,
                                       table_name,
                                       element_id_roads_assoc)
              VALUES (surrogate_key,
                      rec.bridge_number,
                      'D',
                      common_run_date,
                      g_jobname,
                      'ibrdg_roads_assoc_history',
                      rec.element_id);

         cntr_retired := cntr_retired + 1;
         cntr_updated := cntr_updated + 1;
      END LOOP;

      COMMIT;

      SELECT COUNT (*) INTO cntr FROM ibrdg_roads_assoc_history;

      V_flat_file_counts_txt :=
            'bridge roads: '
         || 'Total Rows: '
         || cntr
         || ' Added: '
         || cntr_added
         || ' Updated/New Row Added: '
         || cntr_updated
         || ' Retired:  '
         || cntr_retired;

      WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
         OWNER         => 'WH_ASSETS',
         OBJECT_NAME   => 'ibrdg_roads_assoc_history',
         object_cnt    => cntr,
         add_cnt       => cntr_added,
         update_cnt    => cntr_updated + cntr_retired,
         proc          => $$PLSQL_UNIT,
         start_time    => start_time);
      --wh_common.pkg_common_utilities.UPDATE_WHSE_LOG (g_owner, g_object,cntr,cntr_added, cntr_updated,NULL,NULL);
      wh_common.pkg_common_utilities.EXIT_AND_REPORT (g_jobname,
                                                      'NORMAL',
                                                      V_flat_file_counts_txt);
   ELSE                                                      -- over threshold
      threshold_message :=
            'Unexpected High Update Volume: '
         || cntr
         || ' Update Threshold: '
         || cntr_threshold
         || '. ';


      INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                      ERR_MODULE,
                                      ERR_OID,
                                      ERR_MESSAGE)
           VALUES (SYSDATE,
                   g_jobname,
                   'WH_ASSETS',
                   threshold_message);

      COMMIT;
      wh_common.pkg_common_utilities.exit_and_report ($$PLSQL_UNIT,
                                                      'FAILURE',
                                                      threshold_message);
   END IF;

   SELECT COUNT (*)
     INTO errlog_count
     FROM wh_assets.ibridge_roads_assoc_error_log ;

   IF errlog_count > 0
   THEN
      BEGIN
         err_log_message :=
            'Unexpected Data Quality Issues in roads_under_bridge error log: ';

         INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                         ERR_MODULE,
                                         ERR_OID,
                                         ERR_MESSAGE)
              VALUES (SYSDATE,
                      g_jobname,
                      'WH_ASSETS',
                      err_log_message);
                      
           INSERT INTO data_exceptions (TABLE_NAME,                                
                                      ERROR_CONDITION,                                     
                                      TEST_PROCEDURE,
                                      TEST_DATE,
                                      ASSESSMENT)
                      VALUES ('ibridge_roads_assoc_error_log',
                              'Invalid data - check error log',
                              g_jobname,
                              start_time,
                              'QUALITY');  
           

         COMMIT;
       
      END;
   END IF;
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
         -20050,
         $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
END;
/
