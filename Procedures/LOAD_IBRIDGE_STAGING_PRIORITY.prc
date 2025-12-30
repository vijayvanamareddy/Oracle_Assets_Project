CREATE OR REPLACE PROCEDURE load_ibridge_staging_priority
IS
   /**********************************************************************
   This procedure loads the ibridges staging table with the priority column.
   It uses the highest highway corridor priority (hcp) of: the road on the bridge, and the road(s)
   under the bridge.  Note, the highest priority is the lowest number.
   It is run after the procedure,  load_bridge_roads_staging
   
   It relies on the staging table:  p_staging which is recreated each run

   Date written:  8-Sept-2014, S. Hillson
   Modified: 27-Feb-2015 SH  drop and recreate the staging table using dynamic sql
             10-Aug-2015 SH  changed drop/recreate of the priority staging table to truncate/insert
             08-Jun-2016 SH Copied load_bridge_priority to load_bridge_priority2 to update it for InspectTech bridges and tig segments
                       for the initial load of the ibridges_history table
                       Modified to get priority from roadway_sections rather than from metrans as it was just loaded
           14-Jun-2016 SH  Modified to load ibridges_staging table for weekly refresh
           11-Jul-2016 SH  add standard error handling
           28-Nov-2018 SH - Modify references to roadway_sections view to roadway_sections_history where end_date is null in preparation for going to full network    
           29-Jan-2019 SH - Modify to use full network and GIS segmentation  
           06-Jan-2022 SH - Add a check to ensure the hcp (priority column) is from the highway network and not a rail, trail, or ferry. Added route_type to p_staging.  If a bridge
                            is not associated with a road, the priority is set to null
   **********************************************************************/


   CURSOR prio
   IS
          SELECT b.bridge_number, b.priority
            FROM ibridges_staging b
        ORDER BY b.bridge_number
      FOR UPDATE OF b.priority;

 
 CURSOR element_priority
   IS SELECT bridge_number, b.element_id_on_structure element_id ,  s.priority, e.route_type --  element on bridge
        FROM                                            
            ibridges_staging b, sections s, elements e
       WHERE b.section_id = s.section_id and b.element_id_on_structure = e.element_id
      UNION
      SELECT br.bridge_number, br.element_id,  r.priority, el.route_type --  elements under bridge
        FROM                                         
            ibridge_roads_assoc_staging br, sections r, elements el where br.section_id = r.section_id and br.element_id = el.element_id and br.location_type = 'U' ;
     


   min_priority   ibridges_staging.priority%TYPE;
   cntr           NUMBER := 0;
   start_time     DATE := SYSDATE;
   commit_count   NUMBER := 0;
BEGIN
 

   -- re-load the staging table containing the priority of the highways on and under the bridges
   EXECUTE IMMEDIATE 'TRUNCATE TABLE p_staging';

   FOR e IN element_priority
   LOOP
      INSERT INTO p_staging (bridge_number, element_id, priority,route_type)
           VALUES (e.bridge_number, e.element_id, e.priority,e.route_type);

      commit_count := commit_count + 1;

      IF commit_count > 10000
      THEN
         COMMIT;
         commit_count := 0;
      END IF;
   END LOOP;

   COMMIT;

   -- Update the priority in the bridges table


   FOR p IN prio
   LOOP
      min_priority := NULL;

      SELECT MIN (hp.priority)
        INTO min_priority
        FROM p_staging hp
       WHERE p.bridge_number = hp.bridge_number and route_type in ('I', 'N');


      UPDATE ibridges_staging
         SET priority = min_priority
       WHERE CURRENT OF prio
         LOG ERRORS INTO ibridges_history_error_log
                ('Load Bridge Priority' || SYSDATE)
                REJECT LIMIT 100;
   END LOOP;

   COMMIT;
   

   SELECT COUNT (*) INTO cntr FROM ibridges_staging;

   WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
      OWNER         => 'WH_ASSETS',
      OBJECT_NAME   => 'iBRIDGES_STAGING',
      object_cnt    => cntr,
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
         -20050,
         $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
         
END;
/
