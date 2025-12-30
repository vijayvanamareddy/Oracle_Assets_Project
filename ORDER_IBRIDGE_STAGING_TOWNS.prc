CREATE OR REPLACE PROCEDURE order_ibridge_staging_towns
IS
   /**********************************************************************
   This procedure orders the towns in the ibridge staging table for bridges that span
   two towns. The first town is the one with the lowest mileage on the primary route.
   It then looks up the place code and place code description for the first town.
   
   It is run as part of the ibridges weekly refresh process

   
   6/13/16 SH - Initial Version 
                Modify to use inspect tech bridges, load staging table. rename to order_ibridge_towns
   7/26/16 SH - Add standard error handling
   11-29-2018 SH - Modify references to routes view to routes_history table where end_date is null in preparation for going to full network      
   **********************************************************************/

   CURSOR brdg
   IS
        SELECT b.bridge_number,
               b.town_name1,
               b.towncode,
               b.county,
               b.county_name,
               b.town_name2,
               b.towncode2,
               b.county2,
               b.county2_name,
               r.town,
               r.route_number,
               MIN (r.cumulative_milepoint_order) mp
          FROM routes_history r, ibridges_staging b
         WHERE     r.route_number = b.primary_route_number
               AND r.end_date IS NULL
               AND b.town_name2 IS NOT NULL
               AND (town = b.town_name1 OR town = b.town_name2)
      GROUP BY b.bridge_number,
               b.town_name1,
               b.towncode,
               b.county,
               b.county_name,
               b.town_name2,
               b.towncode2,
               b.county2,
               b.county2_name,
               r.town,
               r.route_number
      ORDER BY b.bridge_number, mp;


   bridge_rec            brdg%ROWTYPE;
   cntr                  NUMBER := 0;
   cntr_updated          NUMBER := 0;
   start_time            DATE := SYSDATE;
   prior_bridge_number   VARCHAR2 (30);
   prior_town            VARCHAR2 (40);
   prior_mp              NUMBER;
   next_bridge_number    VARCHAR2 (30);

   new_placecode         VARCHAR2 (6);
   new_placecode_descr   ibridges_staging.placecode_descr%TYPE;

   PROCEDURE Swap_Towns (towncode1      IN OUT VARCHAR2,
                         towncode2      IN OUT VARCHAR2,
                         town_name1     IN OUT VARCHAR2,
                         town_name2     IN OUT VARCHAR2,
                         county1        IN OUT VARCHAR2,
                         county2        IN OUT VARCHAR2,
                         county_name1   IN OUT VARCHAR2,
                         county_name2   IN OUT VARCHAR2)
   IS
      temp_towncode      VARCHAR2 (5);
      temp_town_name     VARCHAR2 (40);
      temp_county        VARCHAR2 (2);
      temp_county_name   VARCHAR2 (40);
   BEGIN
      temp_towncode := towncode1;
      towncode1 := towncode2;
      towncode2 := temp_towncode;

      temp_town_name := town_name1;
      town_name1 := town_name2;
      town_name2 := temp_town_name;

      temp_county := county1;
      county1 := county2;
      county2 := temp_county;

      temp_county_name := county_name1;
      county_name1 := county_name2;
      county_name2 := temp_county_name;
   END;

   PROCEDURE Write_rec
   IS
   BEGIN
      UPDATE ibridges_staging b
         SET b.town_name1 = bridge_rec.town_name1,
             b.towncode = bridge_rec.towncode,
             b.county = bridge_rec.county,
             b.county_name = bridge_rec.county_name,
             b.town_name2 = bridge_rec.town_name2,
             b.towncode2 = bridge_rec.towncode2,
             b.county2 = bridge_rec.county2,
             b.county2_name = bridge_rec.county2_name,
             b.placecode = SUBSTR (new_placecode, 1, 5),
             b.placecode_descr = new_placecode_descr
       WHERE b.bridge_number = bridge_rec.bridge_number
         LOG ERRORS INTO ibridges_history_error_log ('Order iBridge Towns Error' || sysdate)
                REJECT LIMIT 100;
   END;                                                 -- Procedure Write Rec
BEGIN
  

   OPEN brdg;

   FETCH brdg INTO bridge_rec;

   -- first record

   Prior_bridge_number := bridge_rec.bridge_number;
   prior_mp := bridge_rec.mp;
   prior_town := bridge_rec.town;
   cntr_updated := cntr_updated + 1;


   LOOP
      FETCH brdg INTO bridge_rec;

      EXIT WHEN brdg%NOTFOUND;

      IF prior_bridge_number = bridge_rec.bridge_number -- same bridge as prior
      THEN
         BEGIN                        -- check to see if we need to swap towns
            IF prior_town <> bridge_rec.town_name1       -- need to swap towns
            THEN
               BEGIN
               
                  swap_towns (bridge_rec.towncode,
                              bridge_rec.towncode2,
                              bridge_rec.town_name1,
                              bridge_rec.town_name2,
                              bridge_rec.county,
                              bridge_rec.county2,
                              bridge_rec.county_name,
                              bridge_rec.county2_name);

                  SELECT fips_town_code
                    INTO new_placecode
                    FROM WH_COMMON.DIM_TOWNS t
                   WHERE t.towncode = bridge_rec.towncode;

                  new_placecode_descr :=
                     bridge_description_lookup ('bridge',
                                                'placecode',
                                                SUBSTR (new_placecode, 1, 5),
                                                35);

                  write_rec;
                  Prior_bridge_number := bridge_rec.bridge_number;
               END;
            END IF;
         END;
      ELSE                                                       -- new bridge
         BEGIN
            Prior_bridge_number := bridge_rec.bridge_number;
            prior_mp := bridge_rec.mp;
            prior_town := bridge_rec.town;
         END;
      END IF;
   END LOOP;

   CLOSE brdg;

   -- last record
   IF prior_bridge_number = bridge_rec.bridge_number   -- same bridge as prior
   THEN
      BEGIN                           -- check to see if we need to swap towns
         IF prior_town <> bridge_rec.town_name1          -- need to swap towns
         THEN
            BEGIN
               swap_towns (bridge_rec.towncode,
                           bridge_rec.towncode2,
                           bridge_rec.town_name1,
                           bridge_rec.town_name2,
                           bridge_rec.county,
                           bridge_rec.county2,
                           bridge_rec.county_name,
                           bridge_rec.county2_name);

               SELECT fips_town_code
                 INTO new_placecode
                 FROM WH_COMMON.DIM_TOWNS t
                WHERE t.towncode = bridge_rec.towncode;

 -- No place code description in inspect tech lookup file, so still using pontis


               new_placecode_descr :=
                  bridge_description_lookup ('bridge',
                                             'placecode',
                                             SUBSTR (new_placecode, 1, 5),
                                             35);
             write_rec;
            END;
         END IF;
      END;
   END IF;

   COMMIT;



  SELECT COUNT (*) INTO cntr FROM ibridges_staging;

   WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
      OWNER         => 'WH_ASSETS',
      OBJECT_NAME   => 'IBRIDGES_STAGING',
      object_cnt    => cntr,
      update_cnt    => cntr_updated,
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
