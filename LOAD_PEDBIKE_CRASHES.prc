CREATE OR REPLACE PROCEDURE load_pedbike_crashes
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
09-14-22 SH Add MOTORCYCLE_YN Unit types 11 (Motorcycle), 12  (Moped) Jira Task: DOTDW-640    
            Change cursor crashes from inner join to left outer join between units and people to pick up 'hit and run' or other
            motorcycle crashes with no corresponding person for the unit            
**********************************************************************/

BEGIN
    DECLARE
        CURSOR crashes
        IS
              SELECT au.mdotid,
                     au.unit_type,
                     ac.type_of_crash,
                     ap.person_type
                FROM accidents ac
                     JOIN accident_units Au ON ac.mdotid = au.mdotid
                     LEFT OUTER JOIN accident_people ap
                         ON ac.mdotid = ap.mdotid AND ap.unit_id = au.unit_id
            ORDER BY mdotid;


        rec               crashes%ROWTYPE;

        CURSOR number_of_units
        IS
              SELECT mdotid, COUNT (*) AS unit_count
                FROM accident_units
               WHERE unit_type <> 24                        -- exclude witness
            GROUP BY mdotid;

        CURSOR number_of_persons
        IS
              SELECT mdotid, COUNT (*) AS person_count
                FROM accident_people
               WHERE person_type NOT IN (4, 5) -- exclude owners not in car, witness
            GROUP BY mdotid;
            
        CURSOR driver_in_unit1
        IS
            SELECT mdotid,
                    DRIVER_ACTION1,
                    DRIVER_ACTION1_DESCR,
                    DRIVER_ACTION2,
                    DRIVER_ACTION2_DESCR
               FROM accident_people
              WHERE unit_id = 1 AND person_type IN (1, 6);
        CURSOR driver_in_unit2
        IS
            SELECT mdotid,
                    DRIVER_ACTION1,
                    DRIVER_ACTION1_DESCR,
                    DRIVER_ACTION2,
                    DRIVER_ACTION2_DESCR
               FROM accident_people
              WHERE unit_id = 2 AND person_type IN (1, 6);


        previous_mdotid   accidents.mdotid%TYPE;
        bike_yn           VARCHAR2 (1);
        ped_yn            VARCHAR2 (1);
        motor_cycle_yn    VARCHAR2 (1);
        commit_count      NUMBER;


        err_msg           VARCHAR2 (200);
        g_start_time      DATE := SYSDATE;
        g_owner           VARCHAR2 (20) := 'WH_ASSETS';
        g_jobname         VARCHAR2 (30) := 'LOAD_PEDBIKE_CRASHES';
        g_object          VARCHAR2 (20) := 'ACCIDENTS';
        g_sqlmsg          VARCHAR2 (500) := NULL;
        cntr              NUMBER;
    BEGIN
            OPEN crashes;

        FETCH crashes INTO rec;

        -- Process first record
        bike_yn := 'N';
        ped_yn := 'N';
        motor_cycle_yn := 'N';

        previous_mdotid := rec.mdotid;


        LOOP
            IF    rec.unit_type = 23  -- Bicyclist
               OR rec.type_of_crash = 9  -- Bicycle
               OR rec.person_type = 7 -- Bicycle
            THEN
                bike_yn := 'Y';
            END IF;

            IF    REC.unit_type = 22 -- Pedestrian
               OR REC.type_of_crash = 5 -- Pedestrians
               OR REC.person_type = 3 -- Pedestrian
            THEN
                ped_yn := 'Y';
            END IF;
            
            IF rec.unit_type = 11 -- Motorcycle
            OR rec.unit_type = 12 -- Moded
            THEN motor_cycle_yn := 'Y';
            END IF;

            FETCH crashes INTO rec;

            EXIT WHEN crashes%NOTFOUND;

            IF rec.mdotid <> previous_mdotid
            THEN
                -- we have a new crash
                UPDATE accidents a
                   SET pedestrian_yn = ped_yn, bicycle_yn = bike_yn, motorcycle_yn = motor_cycle_yn
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
                motor_cycle_yn := 'N';
            END IF;
        END LOOP;

        -- Final checks after last row

        UPDATE accidents a
           SET pedestrian_yn = ped_yn, bicycle_yn = bike_yn, motorcycle_yn = motor_cycle_yn
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
        
        FOR d1 in driver_in_unit1
        LOOP
            UPDATE accidents a
              SET a.DRIVER_ACTION1_UNIT1 = d1.DRIVER_ACTION1,
                    a.DRIVER_ACTION1_UNIT1_DESCR = d1.DRIVER_ACTION1_DESCR,
                    a.DRIVER_ACTION2_UNIT1 = d1.DRIVER_ACTION2,
                    a.DRIVER_ACTION2_UNIT1_DESCR = d1.DRIVER_ACTION2_DESCR
             WHERE d1.mdotid = a.mdotid
               LOG ERRORS INTO accidents_error_log
                       ('Load driver in unit1 ' || SYSDATE)
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
        
         FOR d2 in driver_in_unit2
        LOOP
            UPDATE accidents a
              SET a.DRIVER_ACTION1_UNIT2 = d2.DRIVER_ACTION1,
                    a.DRIVER_ACTION1_UNIT2_DESCR = d2.DRIVER_ACTION1_DESCR,
                    a.DRIVER_ACTION2_UNIT2 = d2.DRIVER_ACTION2,
                    a.DRIVER_ACTION2_UNIT2_DESCR = d2.DRIVER_ACTION2_DESCR
             WHERE d2.mdotid = a.mdotid
               LOG ERRORS INTO accidents_error_log
                       ('Load driver in unit2 ' || SYSDATE)
                       REJECT LIMIT 100;

            commit_count := commit_count + 1;

            IF commit_count > 10000
            THEN
                COMMIT;
                commit_count := 0;
            END IF;
        END LOOP;

        COMMIT;
        




        SELECT COUNT (*) INTO cntr FROM ACCIDENTS;

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
END;
/
