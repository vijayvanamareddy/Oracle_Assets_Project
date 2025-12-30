CREATE OR REPLACE PROCEDURE load_ibridge_staging_roads
IS
   /**********************************************************************
   This procedure loads the roads_associated table (ibridge_roads_assoc_staging)
   which contains information about the roads associated with a bridge. 
   It gets the element_ids from metrans. The section_ids are determined 
   using the offsets from metrans.  Additional information about the roads
   are added from InspecTech (where available for inventory routes under the bridge)
   
   It is run weekly as part of the IBRIDGES_WEEKEND_REFRESH procedure and is invoked 
   from the IBRIDGE_ROADS_WEEKLY_REFRESH process

  The view ROADS_UNDER_IBRIDGE, used by obiee, is based on this table

  Modification History:
  3-9-2015  SH - modified to load roads_associated_staging table to keep history
  3-12-2015 SH - added code to check error log
  6-8-2015  SH - modified to only get bridges in the data mart
               - added code to include the roads under the bridge for railroad and pedestrian bridges
  6-25-2015 SH - modified cursor to include ramps as some of the 'O' roads were being excluded
  6-29-2015 SH - Adding primary route number and primary route name columns for the roads
   9-8-2015 SH - Adding roads under the bridge for rail and pedestrian/bicycle bridges
  9-30-2015 SH - Remove Created_by, date_created from staging table
  5-6-2016  SH - Modify to use roadway_sections table (TIG Based segmentation) 
  6-6-2016  SH - Modify to use inspect tech bridges 
                 Modify to only pick up the element id from v_nm_brdg_nw as a road under the bridge if it is a pedestrian bridge
                 and not a railroad bridge to follow changes made in metrans
  7-11-2016 SH - add standard error handling
  9-13-2016 SH - add nbi columns from inspectTech for inventory route under the bridge, named INVRTE_
                 Input is external table, ext_road1_under_bridge
                 Remove join to nm_elements in cursor roads and roads_under_ped_bridge - no longer needed
   9-15-2016 SH - lookup descriptions for INVRTE_ columns from InspecTech
   1-9-2017 SH - modified input to ext_roads_under_bridge which combines 3 roads under bridge (max data in inspecttech)
   2-14-17 SH  - write errors to ibridge_roads_assoc_error_log instead of old log, missed a few
   04-13-17 SH -  Remove code to  pick up the element id from v_nm_brdg_nw as a road under the bridge if it is a pedestrian bridge
                 to follow changes made in metrans
  11-28-2018 SH - Modify  references to roadway_sections view to roadway_sections_history table where end_date is null 
                  and highways view to use highways_history table where end_date is null in preparation for going to full network
 12-11-2018 SH - Replace HIGHWAYS with ELEMENTS and ROADWAY_SECTIONS with SECTIONS   - place bridge on full network
 01-22-2019 SH - Use SECTIONS table with new GIS segmentation
 03-25-2019 SH - Move version in wh_assets_dev to test
 11-26-2019 SH - Add column MTRNS_ASSETNO  (bridge pointer) to provide the relationship for the underclearance height restrictions from InspectTech)
   **********************************************************************/

  
   cntr                            NUMBER;
   start_time                      DATE := SYSDATE;
   err_log_message                 VARCHAR2 (200) := NULL;
   errlog_count                    NUMBER := 0;
  
   -- variables used for descriptions (fe_id and max length of description)  
 
   finvrte_dirsuffix                  NUMBER;
   linvrte_dirsuffix                  NUMBER;
   finvrte_functionclass              NUMBER;
   linvrte_functionclass              NUMBER;
   finvrte_level_of_serv              NUMBER;
   linvrte_level_of_serv              NUMBER;
   finvrte_on_base_hwynet             NUMBER;
   linvrte_on_base_hwynet             NUMBER;
   finvrte_on_nhs                     NUMBER;
   linvrte_on_nhs                     NUMBER; 
   finvrte_on_strahnet                NUMBER;
   linvrte_on_strahnet                NUMBER;
   finvrte_on_trucknet                NUMBER;
   linvrte_on_trucknet                NUMBER;
   finvrte_signprefix                 NUMBER;
   linvrte_signprefix                 NUMBER;  
   finvrte_trafficdir                 NUMBER;
   linvrte_trafficdir                 NUMBER;
   finvrte_toll                       NUMBER;
   linvrte_toll                       NUMBER;
   
     PROCEDURE Lookup_fe_id_length (column_name    IN     VARCHAR2,
                                  insp_fe_id        OUT NUMBER,
                                  max_desc_len      OUT NUMBER)
   IS
   -- Procedure to Look up inspecTech field ID and longest length of description
   BEGIN
      SELECT fe_id
        INTO insp_fe_id
        FROM bridge_mappings
       WHERE assets_column = column_name;

      SELECT MAX (LENGTH (description))
        INTO max_desc_len
        FROM bridges_lookup_codes
       WHERE field_id = insp_fe_id;
   END;
  
 
BEGIN
   DECLARE
      CURSOR roads
      IS
           SELECT b.bridge_id,
                  ne_id_of,
                  location_level,
                  location_type,
                  nm_begin_mp,
                  p.rtcode,
                  p.rtname,
                  iit_primary_key || '-BRPT' MTRNS_ASSETNO  
             FROM v_nm_brpt_nw@metrans b,
                  ibridges_history  br,
                  v_bns_prirte@metrans p
            WHERE    
                  b.bridge_id = br.bridge_number
                  AND ne_id_of = p.ne_id
                  AND br.state = 'CURRENT'
         ORDER BY bridge_id;

      CURSOR roads_to_update
      IS
         SELECT r.bridge_id, r.bridge_number, r.element_id, r.begin_section_offset, r.end_section_offset,
                r.section_id, r.highway_id, r.offset, r.invrte_adt, r.invrte_adt_truck_percent, r.invrte_adt_yr,
                r.invrte_detour_length, r.invrte_dirsuffix, r.invrte_functionclass, r.invrte_level_of_serv,                  
                r.invrte_lrs_rtenum, r.invrte_lrs_subrtenum, r.invrte_on_base_hwynet, r.invrte_on_nhs,                    
                r.invrte_on_strahnet, r.invrte_on_trucknet, r.invrte_rectype, r.invrte_rtenum, 
                r.invrte_signprefix, r.invrte_horiz_clear, r.invrte_min_vert_clear, r.invrte_traffic_dir,
                r.invrte_toll, r.invrte_milepoint  
           FROM ibridge_roads_assoc_staging r
           FOR UPDATE OF  r.section_id, r.highway_id, r.begin_section_offset, r.end_section_offset,
            r.bridge_id, r.invrte_adt, r.invrte_adt_truck_percent, r.invrte_adt_yr, r.invrte_detour_length,
            r.invrte_dirsuffix, r.invrte_functionclass, r.invrte_level_of_serv, r.invrte_lrs_rtenum,  
            r.invrte_lrs_subrtenum, r.invrte_on_base_hwynet, r.invrte_on_nhs, r.invrte_on_strahnet, 
            r.invrte_on_trucknet, r.invrte_rectype, r.invrte_rtenum, r.invrte_signprefix, r.invrte_horiz_clear,
            r.invrte_min_vert_clear, r.invrte_traffic_dir, r.invrte_toll, r.invrte_milepoint;
  
      roads_rec       roads_to_update%ROWTYPE;  
 
      
   BEGIN
   
      EXECUTE IMMEDIATE 'TRUNCATE TABLE ibridge_roads_assoc_staging';
      
   FOR rec IN roads
      LOOP
         INSERT INTO ibridge_roads_assoc_staging (bridge_number,
                                               element_id,
                                               location_level,
                                               location_type,
                                               mtrns_assetno ,
                                               offset,
                                               primary_route_number,
                                               primary_route_name
                                              )
                 VALUES (rec.bridge_id,
                         rec.ne_id_of,
                         rec.location_level,
                         rec.location_type,
                         rec.mtrns_assetno,
                         rec.nm_begin_mp,
                         rec.rtcode,
                         rec.rtname
                         )
                 LOG ERRORS INTO Ibridge_roads_assoc_error_log
                        (   'Procedure: load_ibridge_staging_roads insert into ibridge_roads_assoc_staging failed'
                         || SYSDATE)
                        REJECT LIMIT 100;
      END LOOP;

      COMMIT;

 -- Get the Inspectech fe_id and max length of the description for each _descr column
 
   Lookup_fe_id_length ('INVRTE_DIRSUFFIX',
                        finvrte_dirsuffix,
                        linvrte_dirsuffix);

   Lookup_fe_id_length ('INVRTE_FUNCTIONCLASS',
                        finvrte_functionclass,
                        linvrte_functionclass);
                        
   Lookup_fe_id_length ('ON_BASE_HIGHWAY_NETWORK',finvrte_on_base_hwynet,linvrte_on_base_hwynet );

   Lookup_fe_id_length ('INVRTE_ON_NHS', finvrte_on_nhs, linvrte_on_nhs);
  

   Lookup_fe_id_length ('INVRTE_ON_STRAHNET',
                        finvrte_on_strahnet,
                        linvrte_on_strahnet);
                        
  Lookup_fe_id_length ('INVRTE_ON_TRUCKNET',
                        finvrte_on_trucknet,
                        linvrte_on_trucknet);

   Lookup_fe_id_length ('LEVEL_OF_SERVICE_ON', finvrte_level_of_serv, linvrte_level_of_serv);  
   Lookup_fe_id_length ('KIND_OF_HIGHWAY_ON',finvrte_signprefix,linvrte_signprefix );      
   Lookup_fe_id_length ('TOLL', finvrte_toll, linvrte_toll);
   Lookup_fe_id_length ('TRAFFIC_DIRECTION_ON_BRIDGE',finvrte_trafficdir,linvrte_trafficdir );
                      
       
      OPEN roads_to_update;

      LOOP
         FETCH roads_to_update INTO roads_rec;

         EXIT WHEN roads_to_update%NOTFOUND;
        
         cntr := 0;
        
         -- Get the section_id.  Check to see if the bridge is located on a section boundary
         SELECT COUNT (*)
           INTO cntr
           FROM sections s
          WHERE (    roads_rec.element_id = s.element_id
                 AND roads_rec.offset >= S.BEGIN_OFFSET
                 AND roads_rec.offset <= S.end_OFFSET);

         IF cntr = 1
         THEN
            UPDATE ibridge_roads_assoc_staging b
               SET ( section_id,begin_section_offset,end_section_offset) =
                      (SELECT  S.SECTION_ID, s.begin_offset,s.end_offset
                         FROM sections s
                        WHERE (    b.element_id = s.element_id
                               AND ( (    b.offset >= S.BEGIN_OFFSET
                                      AND b.offset <= S.END_OFFSET))))
             WHERE CURRENT OF roads_to_update
               LOG ERRORS INTO Ibridge_roads_assoc_error_log
                      (   'Procedure: load_ibridge_staging_roads update section id failed '
                       || SYSDATE)
                      REJECT LIMIT 100;
         END IF;

         IF cntr > 1
         THEN -- bridge is on a section boundary, the low order section is chosen
            UPDATE ibridge_roads_assoc_staging b
               SET 
                         
                         ( section_id,begin_section_offset,end_section_offset) =
                      (SELECT  S.SECTION_ID, s.begin_offset,s.end_offset
                         FROM sections s
                        WHERE (    b.element_id = s.element_id
                               AND b.offset > S.BEGIN_OFFSET
                               AND b.offset <= S.END_OFFSET))
             WHERE CURRENT OF roads_to_update
               LOG ERRORS INTO Ibridge_roads_assoc_error_log
                      (   'Procedure: load_ibridge_staging_roads update section id failed '
                       || SYSDATE)
                      REJECT LIMIT 100;
         END IF;

      
         UPDATE ibridge_roads_assoc_staging b
            SET (highway_id) =
                   (SELECT h.element_wid
                      FROM element_history h
                     WHERE h.end_date IS NULL AND b.element_id = h.element_id)
          WHERE CURRENT OF roads_to_update
            LOG ERRORS INTO Ibridge_roads_assoc_error_log
                   (   'Procedure: load_ibridge_staging_roads update HIGHWAY id failed'
                    || SYSDATE)
                   REJECT LIMIT 100;

         UPDATE ibridge_roads_assoc_staging r
            SET (bridge_id) =
                   (SELECT b.bridge_id
                      FROM ibridges_history b
                     WHERE b.bridge_number = r.bridge_number AND b.state = 'CURRENT')
          WHERE CURRENT OF roads_to_update
            LOG ERRORS INTO Ibridge_roads_assoc_error_log
                   (   'Procedure: load_ibridge_staging_roads update BRIDGE id failed'
                    || SYSDATE)
                   REJECT LIMIT 100;
      
      -- Add information about the inventory route under the bridge from InspecTech
                   
                   UPDATE ibridge_roads_assoc_staging b
                   SET 
                        (invrte_adt,  
                        invrte_adt_truck_percent , 
                        invrte_adt_yr  ,
                        invrte_detour_length  ,
                        invrte_dirsuffix,
                        invrte_dirsuffix_descr,
                        invrte_functionclass,  
                        invrte_functionclass_descr,                                       
                        invrte_level_of_serv,   
                        invrte_level_of_serv_descr,               
                        invrte_lrs_rtenum,  
                        invrte_lrs_subrtenum,  
                        invrte_on_base_hwynet, 
                        invrte_on_base_hwynet_descr,             
                        invrte_on_nhs,  
                        invrte_on_nhs_descr,                  
                        invrte_on_strahnet , 
                        invrte_on_strahnet_descr , 
                        invrte_on_trucknet,
                        invrte_on_trucknet_descr,
                        invrte_rectype,
                        invrte_rtenum, 
                        invrte_signprefix,
                        invrte_signprefix_descr,
                        invrte_horiz_clear,
                        invrte_min_vert_clear ,
                        invrte_traffic_dir,
                        invrte_traffic_dir_descr,
                        invrte_toll,
                        invrte_toll_descr,
                        invrte_milepoint         
                         ) = 
                     (SELECT
                        convert_to_number(r.adt),  
                        convert_to_number(r.adt_truck_percent) , 
                        convert_to_number(r.adt_yr),       
                        convert_to_number(r.detour_len)  ,
                        convert_to_number(r.invrte_dirsuffix),
                        bridge_lookup (finvrte_dirsuffix,r.invrte_dirsuffix,linvrte_dirsuffix),                     
                        convert_to_number(r.invrte_functionclass),                      
                        bridge_lookup (finvrte_functionclass,r.invrte_functionclass,linvrte_functionclass),
                        convert_to_number(r.invrte_levsrv),                       
                        bridge_lookup (finvrte_level_of_serv,r.invrte_levsrv,linvrte_level_of_serv),
                        r.invrte_lrs_rtenum,
                        r.invrte_lrs_subrtenum,
                        convert_to_number(r.on_base_hwy),                      
                        bridge_lookup (finvrte_on_base_hwynet,r.on_base_hwy ,linvrte_on_base_hwynet),
                        convert_to_number(r.on_nhs),
                        bridge_lookup (finvrte_on_nhs, r.on_nhs, linvrte_on_nhs),
                        convert_to_number(r.on_strahnet),
                        bridge_lookup (finvrte_on_strahnet, r.on_strahnet, linvrte_on_strahnet),
                        Convert_to_number(substr(r.on_desig_truck_net,1,1)),                       
                        bridge_lookup (finvrte_on_trucknet,substr(r.on_desig_truck_net,1,1), linvrte_on_trucknet),
                        r.invrte_rectype,
                        convert_to_number(r.invrte_rtenum),
                        convert_to_number(r.invrte_signprefix),
                        bridge_lookup (finvrte_signprefix,r.invrte_signprefix,linvrte_signprefix),
                        convert_to_number(r.horiz_clr) ,  
                        convert_to_number(r.min_vert_clr),   
                        convert_to_number(r.traffic_dir),
                        bridge_lookup (finvrte_trafficdir,r.traffic_dir,linvrte_trafficdir),
                        convert_to_number(r.toll),
                        bridge_lookup (finvrte_toll,r.toll, linvrte_toll),
                        convert_to_number(r.milepoint)
                       FROM  ext_roads_under_bridge r
                       WHERE b.bridge_number = r.bridge_number 
                       AND TRIM(LEADING '0' FROM r.invrte_lrs_subrtenum) = TRIM(LEADING '0' FROM b.primary_route_number))
                     WHERE CURRENT OF roads_to_update
                     LOG ERRORS INTO Ibridge_roads_assoc_error_log
                   ('Procedure: load_ibridge_staging_roads update InspecTech road cols failed'
                    || SYSDATE)
                   REJECT LIMIT 100;
                   
                   

                   
      END LOOP;

      CLOSE roads_to_update;

      COMMIT;

      SELECT COUNT (*)
        INTO errlog_count
        FROM ibridge_roads_assoc_error_log;

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
                         'load_ibridge_staging_roads',
                         'WH_ASSETS',
                         err_log_message);

            COMMIT;
            wh_common.pkg_common_utilities.exit_and_report ($$PLSQL_UNIT,
                                                            'FAILURE',
                                                            err_log_message);
         END;
      END IF;
  
        
      SELECT COUNT (*) INTO cntr FROM ibridge_roads_assoc_staging;

   WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
      OWNER         => 'WH_ASSETS',
      OBJECT_NAME   => 'ibridge_roads_assoc_staging',
      object_cnt    => cntr,
      proc          => $$PLSQL_UNIT,
      start_time    => start_time);
      
   COMMIT;

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
END;
/
