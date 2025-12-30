CREATE OR REPLACE PROCEDURE load_pedbike_crashes_new
IS
/**********************************************************************
This procedure adds attributes to the accident table that are determined by
looking at the people and units table.

-  if a crash involves a pedestrian or bicycle
   PED_YN: Calculated where Crash Type, Person Type or Unit Type is Pedestrian
   BICYCLE_YN:Calculated where Crash Type, Person Type or Unit Type is Bicycle or Bicyclist
-  the number of units and number of persons involved in the crash
-  driver actions in units 1 and 2

It is run after loading the accidents, accident_units, and accident_people

07-23-19 SH Initial Version - requested by Shawn MacDonald for viewing in Mapviewer
07-12-22 SH Use dense rank to determine the driver actions in the first 2 units (numeric order) instead of assuming they are numbered
            unit 1 and unit 2.  Jira Task:  DOTDW-666

**********************************************************************/

BEGIN
    DECLARE
        CURSOR crashes IS
              SELECT au.mdotid,
                     au.unit_type,
                     ac.type_of_crash,
                     ap.person_type
                FROM accidents ac
                     JOIN accident_units Au ON ac.mdotid = au.mdotid
                     JOIN accident_people ap
                         ON ac.mdotid = ap.mdotid AND ap.unit_id = au.unit_id
            ORDER BY mdotid;


        rec                           crashes%ROWTYPE;

        CURSOR number_of_units IS
              SELECT mdotid, COUNT (*) AS unit_count
                FROM accident_units
               WHERE unit_type <> 24                        -- exclude witness
            GROUP BY mdotid;

        CURSOR number_of_persons IS
              SELECT mdotid, COUNT (*) AS person_count
                FROM accident_people
               WHERE person_type NOT IN (4, 5) -- exclude owners not in car, witness
            GROUP BY mdotid;

        CURSOR driver_actions IS
              with rankings as (          SELECT a.mdotid,
                             a.unit_id,
                          DENSE_RANK ()
                                 OVER (PARTITION BY a.mdotid
                                       ORDER BY a.unit_id)    AS ds_rn
                        FROM accident_units a
                       WHERE (unit_type IS NULL OR unit_type <> 24) ) -- exclude witness
                      select ap.mdotid,
                            ap.unit_id,
                             ap.DRIVER_ACTION1,
                             ap.DRIVER_ACTION1_DESCR,
                             ap.DRIVER_ACTION2,
                             ap.DRIVER_ACTION2_DESCR,
                             ap.person_type,
                             r.ds_rn
                             from accident_people ap join rankings r on ap.mdotid = r.mdotid and ap.unit_id = r.unit_id 
                             where ap.person_type in (1, 6) order by ap.mdotid, ap.unit_id;

        d                             driver_actions%ROWTYPE;


        previous_mdotid               accidents.mdotid%TYPE;
        bike_yn                       VARCHAR2 (1);
        ped_yn                        VARCHAR2 (1);
        commit_count                  NUMBER;

        tdriver_action1_unit1         accidents.driver_action1_unit1%TYPE;
        tdriver_action1_unit1_descr   accidents.driver_action1_unit1_descr%TYPE;
        tdriver_action2_unit1         accidents.driver_action2_unit1%TYPE;
        tdriver_action2_unit1_descr   accidents.driver_action2_unit1_descr%TYPE;
        tdriver_action1_unit2         accidents.driver_action1_unit2%TYPE;
        tdriver_action1_unit2_descr   accidents.driver_action1_unit2_descr%TYPE;
        tdriver_action2_unit2         accidents.driver_action2_unit2%TYPE;
        tdriver_action2_unit2_descr   accidents.driver_action2_unit2_descr%TYPE;

        err_msg                       VARCHAR2 (200);
        g_start_time                  DATE := SYSDATE;
        g_owner                       VARCHAR2 (20) := 'WH_ASSETS';
        g_jobname                     VARCHAR2 (30) := 'LOAD_PEDBIKE_CRASHES';
        g_object                      VARCHAR2 (20) := 'ACCIDENTS';
        g_sqlmsg                      VARCHAR2 (500) := NULL;
        cntr                          NUMBER;
        
 PROCEDURE display_it_cursor
      IS
      BEGIN
      DBMS_OUTPUT.PUT_LINE ('cursor');
       DBMS_OUTPUT.PUT_LINE ('mdotid: ' || d.mdotid || ' ds_rn: ' || d.ds_rn || ' d.driver action 1 : ' || d.driver_action1 || d.driver_action1_descr ||  ' d.driver action 2 : ' || d.driver_action2 || d.driver_action2_descr);
       
      end;
      
      PROCEDURE display_it_temporary_variables
      IS
      BEGIN
      DBMS_OUTPUT.PUT_LINE ('temp variables');
       DBMS_OUTPUT.PUT_LINE (' tdriver action 1 unit 1 : ' || tdriver_action1_unit1 ||  ' ' ||
                    tdriver_action1_unit1_descr ||
                    ' tdriver action 2 unit 1 : ' || tdriver_action2_unit1 || ' ' ||
                    tdriver_action2_unit1_descr) ;
      DBMS_OUTPUT.PUT_LINE ( ' tdriver action 1 unit 2 :' || tdriver_action1_unit2 ||  ' ' ||
                    tdriver_action1_unit2_descr || 
                    ' tdriver action 2 unit 2 :' || tdriver_action2_unit2 || '  ' || 
                    tdriver_action2_unit2_descr );
       
      end;
      
    BEGIN
    /*
        OPEN crashes;

        FETCH crashes INTO rec;

        -- Process first record
        bike_yn := 'N';
        ped_yn := 'N';

        previous_mdotid := rec.mdotid;


        LOOP
            IF    rec.unit_type = 23                              -- Bicyclist
               OR rec.type_of_crash = 9                             -- Bicycle
               OR rec.person_type = 7                               -- Bicycle
            THEN
                bike_yn := 'Y';
            END IF;

            IF    REC.unit_type = 22                             -- Pedestrian
               OR REC.type_of_crash = 5                         -- Pedestrians
               OR REC.person_type = 3                            -- Pedestrian
            THEN
                ped_yn := 'Y';
            END IF;

            FETCH crashes INTO rec;

            EXIT WHEN crashes%NOTFOUND;

            IF rec.mdotid <> previous_mdotid
            THEN
                -- we have a new crash
                UPDATE accidents a
                   SET pedestrian_yn = ped_yn, bicycle_yn = bike_yn
                 WHERE previous_mdotid = a.mdotid
                   LOG ERRORS INTO accidents_error_log
                           ('Load Bicycle/Pedestrian Crashes ' || SYSDATE)
                           REJECT LIMIT 100;


                commit_count := commit_count + 1;

                IF commit_count > 10000
                THEN
                    COMMIT;
                    commit_count := 0;
                END IF;

                -- process new crash
                previous_mdotid := rec.mdotid;
                bike_yn := 'N';
                ped_yn := 'N';
            END IF;
        END LOOP;

        -- Final checks after last row

        UPDATE accidents a
           SET pedestrian_yn = ped_yn, bicycle_yn = bike_yn
         WHERE previous_mdotid = a.mdotid
           LOG ERRORS INTO accidents_error_log
                   ('Load Bicycle/Pedestrian Crashes ' || SYSDATE)
                   REJECT LIMIT 100;

        COMMIT;

        CLOSE crashes;

        commit_count := 0;

        FOR n IN number_of_units
        LOOP
            UPDATE accidents a
               SET a.no_of_units = n.unit_count
             WHERE n.mdotid = a.mdotid
               LOG ERRORS INTO accidents_error_log
                       ('Load unit count ' || SYSDATE)
                       REJECT LIMIT 100;

            commit_count := commit_count + 1;

            IF commit_count > 10000
            THEN
                COMMIT;
                commit_count := 0;
            END IF;
        END LOOP;

        COMMIT;
        commit_count := 0;

        FOR np IN number_of_persons
        LOOP
            UPDATE accidents a
               SET a.no_of_persons = np.person_count
             WHERE np.mdotid = a.mdotid
               LOG ERRORS INTO accidents_error_log
                       ('Load person count ' || SYSDATE)
                       REJECT LIMIT 100;

            commit_count := commit_count + 1;

            IF commit_count > 10000
            THEN
                COMMIT;
                commit_count := 0;
            END IF;
        END LOOP;

        COMMIT;
        commit_count := 0;
*/
        OPEN driver_actions;

        FETCH driver_actions INTO d;

        -- Process first record
        tdriver_action1_unit1 := NULL;
        tdriver_action1_unit1_descr := NULL;
        tdriver_action2_unit1 := NULL;
        tdriver_action2_unit1_descr := NULL;
        tdriver_action1_unit2 := NULL;
        tdriver_action1_unit2_descr := NULL;
        tdriver_action2_unit2 := NULL;
        tdriver_action2_unit2_descr := NULL;
        
            IF d.ds_rn = 1
            THEN
                BEGIN
                    tdriver_action1_unit1 := d.driver_action1;
                    tdriver_action1_unit1_descr := d.driver_action1_descr;
                    tdriver_action2_unit1 := d.driver_action2;
                    tdriver_action2_unit1_descr := d.driver_action2_descr;
                END;
            ELSE
                IF d.ds_rn = 2
                THEN
                    BEGIN
                        tdriver_action1_unit2 := d.driver_action1;
                        tdriver_action1_unit2_descr := d.driver_action1_descr;
                        tdriver_action2_unit2 := d.driver_action2;
                        tdriver_action2_unit2_descr := d.driver_action2_descr;
                    END;
                END IF;
            END IF;

        previous_mdotid := d.mdotid;
--         DBMS_OUTPUT.PUT_LINE ('first row');
--         display_it_cursor;
 --        display_it_temporary_variables;
       

        LOOP
        

            FETCH driver_actions INTO d;

            EXIT WHEN driver_actions%NOTFOUND;
 --         DBMS_OUTPUT.PUT_LINE ('next row');
 --            display_it_cursor;
        

            IF d.mdotid <> previous_mdotid
            THEN
--                DBMS_OUTPUT.PUT_LINE ('update mdotid: ' || previous_mdotid);
                  
 --        display_it_temporary_variables;
                UPDATE accidents a
                   SET a.driver_action1_unit1 = tdriver_action1_unit1,
                       a.driver_action1_unit1_descr =
                           tdriver_action1_unit1_descr,
                       a.driver_action2_unit1 = tdriver_action2_unit1,
                       a.driver_action2_unit1_descr =
                           tdriver_action2_unit1_descr,
                       a.driver_action1_unit2 = tdriver_action1_unit2,
                       a.driver_action1_unit2_descr =
                           tdriver_action1_unit2_descr,
                       a.driver_action2_unit2 = tdriver_action2_unit2,
                       a.driver_action2_unit2_descr =
                           tdriver_action2_unit2_descr
                 WHERE  a.mdotid = previous_mdotid
                   LOG ERRORS INTO accidents_error_log
                           ('Load driver actions' || SYSDATE)
                           REJECT LIMIT 100;

                commit_count := commit_count + 1;

                IF commit_count > 10000
                THEN
                    COMMIT;
                    commit_count := 0;
                END IF;

                tdriver_action1_unit1 := NULL;
                tdriver_action1_unit1_descr := NULL;
                tdriver_action2_unit1 := NULL;
                tdriver_action2_unit1_descr := NULL;
                tdriver_action1_unit2 := NULL;
                tdriver_action1_unit2_descr := NULL;
                tdriver_action2_unit2 := NULL;
                tdriver_action2_unit2_descr := NULL;
            END IF;
                IF d.ds_rn = 1
                THEN
                    BEGIN
                        tdriver_action1_unit1 := d.driver_action1;
                        tdriver_action1_unit1_descr := d.driver_action1_descr;
                        tdriver_action2_unit1 := d.driver_action2;
                        tdriver_action2_unit1_descr := d.driver_action2_descr;
                    END;
                ELSE
                    IF d.ds_rn = 2
                    THEN
                        BEGIN
                            tdriver_action1_unit2 := d.driver_action1;
                            tdriver_action1_unit2_descr :=
                                d.driver_action1_descr;
                            tdriver_action2_unit2 := d.driver_action2;
                            tdriver_action2_unit2_descr :=
                                d.driver_action2_descr;
                        END;
                    END IF;
                END IF;
            
              previous_mdotid := d.mdotid;
        END LOOP;
        
         -- Final checks after last row
--       DBMS_OUTPUT.PUT_LINE ('update last mdotid: ' || previous_mdotid);

--         display_it_temporary_variables;
        UPDATE accidents a
                   SET a.driver_action1_unit1 = tdriver_action1_unit1,
                       a.driver_action1_unit1_descr =
                           tdriver_action1_unit1_descr,
                       a.driver_action2_unit1 = tdriver_action2_unit1,
                       a.driver_action2_unit1_descr =
                           tdriver_action2_unit1_descr,
                       a.driver_action1_unit2 = tdriver_action1_unit2,
                       a.driver_action1_unit2_descr =
                           tdriver_action1_unit2_descr,
                       a.driver_action2_unit2 = tdriver_action2_unit2,
                       a.driver_action2_unit2_descr =
                           tdriver_action2_unit2_descr
                 WHERE  a.mdotid = previous_mdotid
                   LOG ERRORS INTO accidents_error_log
                           ('Load driver actions' || SYSDATE)
                           REJECT LIMIT 100;

        COMMIT;

        CLOSE driver_actions;

        
        SELECT COUNT (*) INTO cntr FROM ACCIDENTS;
        
        /*

        WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
            OWNER         => G_OWNER,
            OBJECT_NAME   => g_object,
            object_cnt    => cntr,
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
            RAISE_APPLICATION_ERROR (-20010, G_SQLMSG);
    END;
    */
    EXCEPTION 


WHEN OTHERS THEN
DBMS_OUTPUT.PUT_LINE('UNEXPECTED ERROR: '  || TO_CHAR(SQLCODE) || ' ' || SUBSTR(SQLERRM, 1,60)) ;


END;
END;
/
