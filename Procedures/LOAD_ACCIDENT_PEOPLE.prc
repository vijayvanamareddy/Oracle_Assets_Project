CREATE OR REPLACE PROCEDURE load_accident_people
IS
    /**********************************************************************
    This procedure loads the ACCIDENTS_PEOPLE table from CRASH.

    It truncates the table and re-loads it.

    05-17-17 SH  Initial Version
    07-25-17 SH  Add license_state_descr
    08-01-17 SH Modified to use local function call to get injury count (f_getinjurycount) based on local materialized view, MV_CRASH_INJURYCOUNT
    08-17-17 SH Remove crash_id, add standard error handling, run weekly in assets_cycle
    09-13-17 SH Use accidents table to determine if the information about the people should be loaded into the warehouse
    09-19-17 SH Use implicit cursor for lookups Function crash_lookupi
                Backout using accidents table to determine if people should be loaded into the warehouse
    01-07-19 SH Set indexes unusable prior to loading/rebuild them after loading to improve performance using the MANAGE_INDEXES Package   
    09-19-19 SH Add crashreportid and only add crashes in the accidents table in preparation for loading people daily
    04-06-21 SH Add columns DRIVER_DISTRACTED_BY_ACTION, DRIVER_DISTRACTED_BY_SOURCE and their descriptions
    11-21-23 DG DOTDW-855 Add columns LAW_ENF_SUSPECTS_ALCOHOL_USE and LAW_ENF_SUSPECTS_DRUG_USE
    **********************************************************************/



    commit_count                   NUMBER  := 0;
    cntr                           NUMBER  := 0;

    g_start_time                   DATE := SYSDATE;
    g_owner                        VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                      VARCHAR2 (30) := 'LOAD_ACCIDENT_PEOPLE';
    g_object                       VARCHAR2 (20) := 'ACCIDENT_PEOPLE';
    g_sqlmsg                       VARCHAR2 (500) := NULL;



    tairbag_deployed_descr         accident_people.airbag_deployed_descr%type;
    talcohol_test_descr            accident_people.alcohol_test_descr%type;
    tbicyclist_maneuvers_descr     accident_people.bicyclist_maneuvers_descr%type;
    tcond_time_of_crash_descr      accident_people.cond_time_of_crash_descr%type;
    tdriver_action1_descr          accident_people.driver_action1_descr%type;
    tdriver_action2_descr          accident_people.driver_action2_descr %type;
    tdriver_distracted_descr       accident_people.driver_distracted_descr%type;
    tdriver_distracted_by_action_descr  accident_people.driver_distracted_by_action_descr%type;
    tdriver_distracted_by_source_descr  accident_people.driver_distracted_by_source_descr%type;
    tdrug_test_descr               accident_people.drug_test_descr%type;
    tejected_descr                 accident_people.ejected_descr%type;
    thelmet_use_descr              accident_people.helmet_use_descr%type;
    tinjury_area_descr             accident_people.injury_area_descr%type;
    tinjury_degree_descr          accident_people.injury_degree_descr%type;
    tinjury_type_descr            accident_people.injury_type_descr%type;
    tlicense_state_descr           accident_people.license_state_descr%type;
    tlicense_status_descr          accident_people.license_status_descr%type;
    tnonmotor_act1_time_of_descr   accident_people.nonmotor_act1_time_of_descr%type;
    tnonmotor_act2_time_of_descr   accident_people.nonmotor_act2_time_of_descr%type;
    tnonmotor_act_prior_descr      accident_people.nonmotor_act_prior_descr%type;
    tnonmotor_location_descr       accident_people.nonmotor_location_descr%type;
    tpedestrian_maneuvers_descr    accident_people.pedestrian_maneuvers_descr%type;
    tperson_sex_descr               accident_people.person_sex_descr%type;
    tperson_type_descr             accident_people.person_type_descr%type;
    trestraint_system_descr        accident_people.restraint_system_descr%type;
    tseat_position_other_descr     accident_people.seat_position_other_descr%type;
    tseat_position_row_descr       accident_people.seat_position_row_descr%type;
    tseat_position_seat_descr      accident_people.seat_position_seat_descr%type;
    tviolation1_descr              accident_people.violation1_descr%type;
    tviolation2_descr              accident_people.violation2_descr%type;
    tlaw_enf_suspects_alcohol_use  accident_people.law_enf_suspects_alcohol_use%type;
    tlaw_enf_suspects_drug_use     accident_people.law_enf_suspects_drug_use%type;


    CURSOR acc
    IS
        SELECT a.mdotid,
               p.crashreportid,
               a.accident_year,
               p.airbagdeployed,
               p.alcoholtest,
               p.bicyclistmaneuvers,
               p.conditionattimeofcrash,
               p.driveractionsattimeofcrash1,
               p.driveractionsattimeofcrash2,
               p.driverdistractedby,
               p.distractedbyaction,
               p.distractedbysource,
               p.drugtest,
               p.ejected,
               p.helmetuse,
               p.injuryarea,
               p.injurydegree,
               p.injurytype,
               p.licensestate,
               p.licensestatus,
               p.nonmotoristactionpriortocrash,
               p.nonmotoristactiontimeofcrash1,
               p.nonmotoristactiontimeofcrash2,
               p.nonmotoristlocationtimeofcrash,
               p.pedestrianmaneuvers,
               CASE
                   WHEN (P.dateofbirth < '01-JAN-1850') THEN 999
                   ELSE TRUNC ( (a.accident_date - p.dateofbirth) / 365.24, 0)
               END
               person_age,
               p.personid,
               p.persontype,
               p.restraintsystem,
               p.seatpositionother,
               p.seatpositionrow,
               p.seatpositionseat,
               p.seatpostionother,
               p.sex,
               p.unitid,
               p.violation1,
               p.violation2,
               p.lawenforcesuspectsalcoholuse,
               p.lawenforcesuspectsdruguse   
           FROM accidents a, persons@CRASH P
           WHERE p.crashreportid = a.crashreportid;

BEGIN
   EXECUTE IMMEDIATE 'TRUNCATE TABLE ACCIDENT_PEOPLE';

   EXECUTE IMMEDIATE 'TRUNCATE TABLE ACCIDENT_PEOPLE_ERROR_LOG';
    
   MANAGE_INDEXES.Mark_Indexes_Unusable ('ACCIDENT_PEOPLE');
   
 FOR a IN acc
    LOOP
        -- Lookup descriptions

        IF a.airbagdeployed IS NULL 
        THEN tairbag_deployed_descr := NULL;
        ELSE tairbag_deployed_descr :=   crash_lookupi ('AIR_BAG_DEPLOYED', a.airbagdeployed);
        END IF;

        IF a.alcoholtest IS NULL 
        THEN talcohol_test_descr := NULL;
        ELSE talcohol_test_descr := crash_lookupi ('ALCOHOL_TESTS', a.alcoholtest);
        END IF;

        IF a.bicyclistmaneuvers IS NULL 
        THEN tbicyclist_maneuvers_descr := NULL;
        ELSE tbicyclist_maneuvers_descr :=  crash_lookupi ('BICYCLIST_MANEUVERS', a.bicyclistmaneuvers);
        END IF;
  
        IF a.conditionattimeofcrash IS NULL 
        THEN  tcond_time_of_crash_descr := NULL;
        ELSE  tcond_time_of_crash_descr :=  crash_lookupi ('CONDITION_AT_TIME_OF_CRASH', a.conditionattimeofcrash);
        END IF;      
                
        IF a.driveractionsattimeofcrash1 IS NULL 
        THEN tdriver_action1_descr := NULL;                   
        ELSE tdriver_action1_descr := crash_lookupi ('DRIVER_ACTIONS_AT_TIME_OF_CRASH',a.driveractionsattimeofcrash1);
        END IF;  

        IF a.driveractionsattimeofcrash2 IS NULL 
        THEN tdriver_action2_descr := NULL;
        ELSE tdriver_action2_descr := crash_lookupi ('DRIVER_ACTIONS_AT_TIME_OF_CRASH', a.driveractionsattimeofcrash2);
        END IF;  

        IF a.driverdistractedby IS NULL 
        THEN tdriver_distracted_descr := NULL;
        ELSE tdriver_distracted_descr := crash_lookupi ('DRIVER_DISTRACTED', a.driverdistractedby);
        END IF;  
        
        IF a.distractedbyaction IS NULL 
        THEN tdriver_distracted_by_action_descr  := NULL;
        ELSE tdriver_distracted_by_action_descr  := crash_lookupi ('DISTRACTED_BY_ACTION', a.distractedbyaction);
        END IF;  
        
        IF a.distractedbysource IS NULL 
        THEN tdriver_distracted_by_source_descr  := NULL;
        ELSE tdriver_distracted_by_source_descr  := crash_lookupi ('DISTRACTED_BY_SOURCE', a.distractedbysource);
        END IF;  

        IF a.drugtest IS NULL 
        THEN tdrug_test_descr := NULL;
        ELSE tdrug_test_descr := crash_lookupi ('DRUG_TEST', a.drugtest);
        END IF;  
        
        IF a.ejected IS NULL 
        THEN  tejected_descr := NULL;
        ELSE  tejected_descr := crash_lookupi ('EJECTED', a.ejected);
        END IF;  
        
        IF a.helmetuse IS NULL 
        THEN thelmet_use_descr := NULL;
        ELSE thelmet_use_descr := crash_lookupi ('HELMET_USE', a.helmetuse);
        END IF;  
                
        IF a.injuryarea IS NULL 
        THEN  tinjury_area_descr := NULL;
        ELSE tinjury_area_descr := crash_lookupi ('INJURY_AREA', a.injuryarea);
        END IF;  
                
        IF a.injurydegree IS NULL 
        THEN  tinjury_degree_descr := NULL;
        ELSE tinjury_degree_descr := crash_lookupi ('INJURY_DEGREE', a.injurydegree);
        END IF;  
                    
        IF a.injurytype IS NULL 
        THEN tinjury_type_descr := NULL;
        ELSE tinjury_type_descr := crash_lookupi ('INJURY_TYPE', a.injurytype);
        END IF;  
                
        IF a.licensestate IS NULL 
        THEN tlicense_state_descr := NULL;
        ELSE tlicense_state_descr := crash_lookupi ('LICENSE_STATE',a.licensestate);
        END IF;  
                    
        IF a.licensestatus IS NULL 
        THEN tlicense_status_descr := NULL;
        ELSE tlicense_status_descr := crash_lookupi ('LICENSE_STATUS', a.licensestatus);
        END IF;  
                    
        IF a.nonmotoristactiontimeofcrash1 IS NULL 
        THEN tnonmotor_act1_time_of_descr := NULL;
        ELSE tnonmotor_act1_time_of_descr := crash_lookupi ('NONMOTORIST_ACT_TIME_OF_CRASH', a.nonmotoristactiontimeofcrash1);
        END IF;  
                                  
        IF a.nonmotoristactiontimeofcrash2 IS NULL 
        THEN tnonmotor_act2_time_of_descr := NULL;
        ELSE tnonmotor_act2_time_of_descr := crash_lookupi ('NONMOTORIST_ACT_TIME_OF_CRASH', a.nonmotoristactiontimeofcrash2);
        END IF;  
                                  
        IF a.nonmotoristactionpriortocrash IS NULL 
        THEN tnonmotor_act_prior_descr := NULL;
        ELSE tnonmotor_act_prior_descr := crash_lookupi ('NONMOTORIST_ACT_PRIOR_TO_CRASH', a.nonmotoristactionpriortocrash);
        END IF;  
                                  
        IF a.nonmotoristlocationtimeofcrash IS NULL 
        THEN tnonmotor_location_descr := NULL;
        ELSE tnonmotor_location_descr := crash_lookupi ('NONMOTORIST_LOC_TIME_OF_CRASH', a.nonmotoristlocationtimeofcrash);
        END IF;  
                                  
        IF a.pedestrianmaneuvers IS NULL 
        THEN tpedestrian_maneuvers_descr := NULL;
        ELSE tpedestrian_maneuvers_descr := crash_lookupi ('PEDESTRIAN_MANEUVERS', a.pedestrianmaneuvers);
        END IF;  
                    
        IF a.sex IS NULL 
        THEN tperson_sex_descr := NULL;
        ELSE tperson_sex_descr := crash_lookupi ('SEX', a.sex);
        END IF;  
               
        IF a.persontype IS NULL 
        THEN  tperson_type_descr := NULL;
        ELSE tperson_type_descr := crash_lookupi ('PERSON_TYPE', a.persontype);
        END IF;  
                
        IF a.restraintsystem IS NULL 
        THEN trestraint_system_descr := NULL;
        ELSE trestraint_system_descr := crash_lookupi ('RESTRAINT_SYSTEM', a.restraintsystem);
        END IF;  
                    
        IF a.seatpostionother IS NULL 
        THEN tseat_position_other_descr := NULL;
        ELSE tseat_position_other_descr := crash_lookupi ('SEAT_POSITION_OTHER', a.seatpostionother);
        END IF;  
                    
        IF a.seatpositionrow IS NULL 
        THEN tseat_position_row_descr := NULL;
        ELSE tseat_position_row_descr := crash_lookupi ('SEAT_POSITION_ROW', a.seatpositionrow);
        END IF;  
                    
        IF a.seatpositionseat IS NULL 
        THEN tseat_position_seat_descr := NULL;
        ELSE tseat_position_seat_descr := crash_lookupi ('SEAT_POSITION_SEAT', a.seatpositionseat);
        END IF;  

        IF a.violation1 IS NULL 
        THEN  tviolation1_descr := NULL;
        ELSE tviolation1_descr := crash_lookupi ('VIOLATIONS', a.violation1);
        END IF;  
                
        IF a.violation2 IS NULL 
        THEN tviolation2_descr := NULL;
        ELSE tviolation2_descr := crash_lookupi ('VIOLATIONS', a.violation2);
        END IF;  
        
        IF a.lawenforcesuspectsalcoholuse IS NULL 
        THEN tlaw_enf_suspects_alcohol_use := NULL;
        ELSE tlaw_enf_suspects_alcohol_use := crash_lookupi ('YES_NO_UNKOWN', a.lawenforcesuspectsalcoholuse);
        END IF;  
        
        IF a.lawenforcesuspectsdruguse IS NULL 
        THEN tlaw_enf_suspects_drug_use := NULL;
        ELSE tlaw_enf_suspects_drug_use := crash_lookupi ('YES_NO_UNKOWN', a.lawenforcesuspectsdruguse);
        END IF; 
       
        INSERT INTO accident_people (accident_year,
                                     airbag_deployed,
                                     airbag_deployed_descr,
                                     alcohol_test,
                                     alcohol_test_descr,
                                     bicyclist_maneuvers,
                                     bicyclist_maneuvers_descr,
                                     cond_time_of_crash,
                                     cond_time_of_crash_descr,
                                     crashreportid,
                                     driver_action1,
                                     driver_action1_descr,
                                     driver_action2,
                                     driver_action2_descr,
                                     driver_distracted,
                                     driver_distracted_descr,
                                     driver_distracted_by_action,
                                     driver_distracted_by_action_descr,
                                     driver_distracted_by_source,
                                     driver_distracted_by_source_descr,
                                     drug_test,
                                     drug_test_descr,
                                     ejected,
                                     ejected_descr,
                                     helmet_use,
                                     helmet_use_descr,
                                     injury_area,
                                     injury_area_descr,
                                     injury_degree,
                                     injury_degree_descr,
                                     injury_type,
                                     injury_type_descr,
                                     license_state,
                                     license_state_descr,
                                     license_status,
                                     license_status_descr,
                                     mdotid,
                                     nonmotor_act1_time_of_descr,
                                     nonmotor_act2_time_of_descr,
                                     nonmotor_act_prior,
                                     nonmotor_act_prior_descr,
                                     nonmotor_act_time_of_crash1,
                                     nonmotor_act_time_of_crash2,
                                     nonmotor_location,
                                     nonmotor_location_descr,
                                     pedestrian_maneuvers,
                                     pedestrian_maneuvers_descr,
                                     person_age,
                                     person_id,
                                     person_sex,
                                     person_sex_descr,
                                     person_type,
                                     person_type_descr,
                                     restraint_system,
                                     restraint_system_descr,
                                     seat_position_other,
                                     seat_position_other_descr,
                                     seat_position_row,
                                     seat_position_row_descr,
                                     seat_position_seat,
                                     seat_position_seat_descr,
                                     unit_id,
                                     violation1,
                                     violation1_descr,
                                     violation2,
                                     violation2_descr,
                                     law_enf_suspects_alcohol_use,
                                     law_enf_suspects_drug_use)
             VALUES (a.accident_year,
                     a.airbagdeployed,
                     tairbag_deployed_descr,
                     a.alcoholtest,
                     talcohol_test_descr,
                     a.bicyclistmaneuvers,
                     tbicyclist_maneuvers_descr,
                     a.conditionattimeofcrash,
                     tcond_time_of_crash_descr,
                     a.crashreportid,
                     a.driveractionsattimeofcrash1,
                     tdriver_action1_descr,
                     a.driveractionsattimeofcrash2,
                     tdriver_action2_descr,
                     a.driverdistractedby,
                     tdriver_distracted_descr,
                     a.distractedbyaction,
                     tdriver_distracted_by_action_descr,
                     a.distractedbysource,
                     tdriver_distracted_by_source_descr,
                     a.drugtest,
                     tdrug_test_descr,
                     a.ejected,
                     tejected_descr,
                     a.helmetuse,
                     thelmet_use_descr,
                     a.injuryarea,
                     tinjury_area_descr,
                     a.injurydegree,
                     tinjury_degree_descr,
                     a.injurytype,
                     tinjury_type_descr,
                     a.licensestate,
                     tlicense_state_descr,
                     a.licensestatus,
                     tlicense_status_descr,
                     a.mdotid,
                     tnonmotor_act1_time_of_descr,
                     tnonmotor_act2_time_of_descr,
                     a.nonmotoristactionpriortocrash,
                     tnonmotor_act_prior_descr,
                     a.nonmotoristactiontimeofcrash1,
                     a.nonmotoristactiontimeofcrash2,
                     a.nonmotoristlocationtimeofcrash,
                     tnonmotor_location_descr,
                     a.pedestrianmaneuvers,
                     tpedestrian_maneuvers_descr,
                     a.person_age,
                     a.personid,
                     a.sex,
                     tperson_sex_descr,
                     a.persontype,
                     tperson_type_descr,
                     a.restraintsystem,
                     trestraint_system_descr,
                     a.seatpositionother,
                     tseat_position_other_descr,
                     a.seatpositionrow,
                     tseat_position_row_descr,
                     a.seatpositionseat,
                     tseat_position_seat_descr,
                     a.unitid,
                     a.violation1,
                     tviolation1_descr,
                     a.violation2,
                     tviolation2_descr,
                     tlaw_enf_suspects_alcohol_use,
                     tlaw_enf_suspects_drug_use)
                LOG ERRORS INTO accident_people_error_log
                        ('LOAD ACCIDENT PEOPLE ' || SYSDATE)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 100000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
        
    END LOOP;

    COMMIT;

   MANAGE_INDEXES.Rebuild_Unusable_Indexes( 'ACCIDENT_PEOPLE');

select count(*) into cntr from ACCIDENT_PEOPLE;
WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (OWNER => G_OWNER, OBJECT_NAME => g_object,
       object_cnt => cntr,
       proc => $$PLSQL_UNIT, start_time => g_start_time);
EXCEPTION WHEN OTHERS THEN
      G_SQLMSG := $$PLSQL_UNIT||': '||SUBSTR(SQLERRM,1,400);
      WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG
      (OWNER => G_OWNER, OBJECT_NAME => g_object, MSG => G_SQLMSG, STATUS => 'Failed');

      WH_COMMON.PKG_COMMON_UTILITIES.EXIT_AND_REPORT(g_jobname,'FAILURE',$$PLSQL_UNIT||' '||SUBSTR(SQLERRM,1,400));
      RAISE_APPLICATION_ERROR(-20010,G_SQLMSG);
END;
/
