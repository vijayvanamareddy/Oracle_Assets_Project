CREATE OR REPLACE PROCEDURE load_accident_units_test
IS
    /**********************************************************************
    This procedure loads the ACCIDENT_UNITS table from CRASH.

    It truncates the table and re-loads it.

    07-12-17 SH  Initial Version
    08-01-17 SH Modified to use local function call to get injury count (f_getinjurycount) based on local materialized view, MV_CRASH_INJURYCOUNT
    08-17-17 SH Remove crash_id, add standard error handling, run weekly in assets_cycle, add direction_of_travel, direction_of_travel_descr
    08-21-17 SH Add EMERGENCYVEHRESPONDINGTOCALL, EXEMPTVEHICLE
             Modify exception code to not write to data_exceptions if there are just witnesses
    09-13-17 SH Add fixed_object_struck,fixed_object_struck_descr
             Use accidents table to determine if the information about the units should be loaded into the warehouse
    09-18-17 SH Use implicit cursor for lookups Function crash_lookupi)
             backout change:      crash_report_id (natural key in CRASH to improve performance loading accident_units and accident_people)
             Use accidents table to determine if the information about the units should be loaded into the warehouse
    01-24-18 TAM Removed Fix Object Struct
    01-07-19 SH Set indexes unusable prior to loading/rebuild them after loading to improve performance using the MANAGE_INDEXES Package
    09-19-19 SH  Add crashreportid and only add crashes in the accidents table in preparation for loading units daily
    11-25-19 SH Add new columns: VEHICLE_MAKE, VEHICLE_MAKE_DESCR, VEHICLE_COLOR, VEHICLE_COLOR_DESCR  (Shawn Hembree request)
    04-07-21 SH Add new columns:AUTOMATION_LEVELS_ENGAGED,  AUTOMATION_LEVELS_ENGAGED_DESCR, AUTOMATION_LEVELS_IN_VEHICLE,
                AUTOMATION_LEVELS_IN_VEHICLE_DESCR, AUTOMATION_SYSTEM_IN_VEHICLE
    07-12-22 SH Add new columns: MOST_DAMAGED_AREA, MOST_DAMAGED_AREA_DESCR (Jira Task: DOTDW-680)
    **********************************************************************/

    maxlen                                INTEGER;
    curlen                                INTEGER;

    commit_count                          NUMBER (7) := 0;
    cntr                                  NUMBER (7) := 0;

    g_start_time                          DATE := SYSDATE;
    g_owner                               VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                             VARCHAR2 (30) := 'LOAD_ACCIDENT_UNITS';
    g_object                              VARCHAR2 (20) := 'ACCIDENT_UNITS';
    g_sqlmsg                              VARCHAR2 (500) := NULL;

    tcntrib_circum_descr                  accident_units.cntrib_circum_descr%TYPE; -- 60,46
    tdirection_of_travel_descr            accident_units.direction_of_travel_descr%TYPE; -- 50,14
    temerg_veh_responding_to_call         accident_units.emerg_veh_responding_to_call%TYPE; -- 3,3
    texempt_vehicle                       accident_units.exempt_vehicle%TYPE; -- 3,3
    textent_of_damage_descr               accident_units.extent_of_damage_descr%TYPE; -- 50,29
    tgvwr_or_gcwr_descr                   accident_units.gvwr_or_gcwr_descr%TYPE; -- 100,24
    thazmat_placard_descr                 accident_units.hazmat_placard_descr%TYPE; -- 50,3
    thit_and_run_descr                    accident_units.hit_and_run_descr%TYPE; -- 10,3
    tlicense_state_descr                  accident_units.license_state_descr%TYPE; -- 40,30
    tmost_harmful_event_descr             accident_units.most_harmful_event_descr%TYPE; -- 100,76
    tnine_or_more_seats_descr             accident_units.nine_or_more_seats_descr%TYPE; -- 10,3
    tprecrash_actions_descr               accident_units.precrash_actions_descr%TYPE; -- 60,54
    tseq_of_events1_descr                 accident_units.seq_of_events1_descr%TYPE; -- 100,76
    tseq_of_events2_descr                 accident_units.seq_of_events2_descr%TYPE; -- 100,76
    tseq_of_events3_descr                 accident_units.seq_of_events3_descr%TYPE; -- 100,76
    tseq_of_events4_descr                 accident_units.seq_of_events4_descr%TYPE; -- 100,76
    tspecial_func_vehicle_descr           accident_units.special_func_vehicle_descr%TYPE; -- 100,26
    tunit_type_descr                      accident_units.unit_type_descr%TYPE; -- 55, 42
    tvehicle_config_descr                 accident_units.vehicle_config_descr%TYPE; -- 100,66
    tvehicle_color_descr                  accident_units.vehicle_color_descr%TYPE; -- 20, 19
    tvehicle_make_descr                   accident_units.vehicle_make_descr%TYPE; -- 20,15

    tautomation_levels_engaged_descr      accident_units.automation_levels_engaged_descr%TYPE; -- 50,24
    tautomation_levels_in_vehicle_descr   accident_units.automation_levels_in_vehicle_descr%TYPE; -- 50,24
    tautomation_system_in_vehicle         accident_units.automation_system_in_vehicle%TYPE; -- 3,7
    tmost_damaged_area_descr              accident_units.most_damaged_area_descr%TYPE; -- 100,29


    CURSOR acc IS
        SELECT ac.accident_year,
               u.automationlevelsengaged,
               u.automationlevelsinvehicle,
               u.automationsysteminvehicle,
               u.crashreportid,
               u.contribcircumstancesvehicle,
               u.emergencyvehrespondingtocall,
               u.exemptvehicle,
               u.extentofdamage,
               u.gvwrorgcwr,
               u.hazmatplacarded,
               u.hitandrun,
               u.licenseplatenumber,
               u.licenseplatestate,
               ac.mdotid,
               u.mostdamagedarea,
               u.mostharmfulevent,
               u.vehiclehas9ormoreseats,
               u.precrashactions,
               u.sequenceofevents1,
               u.sequenceofevents2,
               u.sequenceofevents3,
               u.sequenceofevents4,
               u.specialfunctionvehicle,
               u.unitid,
               u.unittype,
               u.vehiclecolor,
               u.vehicleconfiguration,
               u.vehiclemake,
               u.vehicletraveldirection,
               u.vin
          FROM accidents  ac
               JOIN units@crash u ON u.crashreportid = ac.crashreportid;


--file_handle UTL_FILE.FILE_TYPE;
--v_line      VARCHAR2(32767) := 'This is a test line to be written to the file.';
  
BEGIN

maxlen := 0;

--file_handle := UTL_FILE.FOPEN('EXT_DIR_FTPROOT', 'test_file.txt', 'w'); 

    --EXECUTE IMMEDIATE 'TRUNCATE TABLE ACCIDENT_UNITS';

    --EXECUTE IMMEDIATE 'TRUNCATE TABLE ACCIDENT_UNITS_ERROR_LOG';

    --MANAGE_INDEXES.Mark_Indexes_Unusable ('ACCIDENT_UNITS');

    FOR a IN acc
    LOOP
   
        -- Lookup descriptions
--UTL_FILE.PUT_LINE(file_handle,'tautomation_levels_engaged_descr');
/*
        IF a.automationlevelsengaged IS NOT NULL
        THEN
            tautomation_levels_engaged_descr :=
                crash_lookupi ('AUTOMATION_LEVELS',
                               TO_CHAR (a.automationlevelsengaged));
        ELSE
            tautomation_levels_engaged_descr := NULL;
        END IF;
*/
/*
IF a.automationlevelsengaged IS NOT NULL THEN
  curlen := length(crash_lookupi ('AUTOMATION_LEVELS', TO_CHAR (a.automationlevelsengaged)));
ELSE
  curlen := 0;
END IF;    
*/
/*       
--UTL_FILE.PUT_LINE(file_handle,'tautomation_levels_in_vehicle_descr');
        IF a.automationlevelsinvehicle IS NOT NULL
        THEN
            tautomation_levels_in_vehicle_descr :=
                crash_lookupi ('AUTOMATION_LEVELS',
                               TO_CHAR (a.automationlevelsinvehicle));
        ELSE
            tautomation_levels_in_vehicle_descr := NULL;
        END IF;
*/
/*
IF a.automationlevelsinvehicle IS NOT NULL THEN
  curlen := length(crash_lookupi ('AUTOMATION_LEVELS', TO_CHAR (a.automationlevelsinvehicle)));
ELSE
  curlen := 0;
END IF;
*/    
      
--UTL_FILE.PUT_LINE(file_handle,'tautomation_system_in_vehicle');
/*
        IF    a.automationsysteminvehicle IS NULL
           OR a.automationsysteminvehicle = 0
        THEN
            tautomation_system_in_vehicle := NULL;
        ELSE
            tautomation_system_in_vehicle :=
                crash_lookupi ('YES_NO_UNKOWN',
                               TO_CHAR (a.automationsysteminvehicle));
        END IF;
*/
/*
IF    a.automationsysteminvehicle IS NULL
           OR a.automationsysteminvehicle = 0 THEN
  curlen := 0;
ELSE  
  curlen := length(crash_lookupi ('YES_NO_UNKOWN', TO_CHAR (a.automationsysteminvehicle)));
END IF;
*/    
      
--UTL_FILE.PUT_LINE(file_handle,'tcntrib_circum_descr');
        IF a.contribcircumstancesvehicle IS NOT NULL
        THEN
            tcntrib_circum_descr :=
                crash_lookupi ('CONTRIB_CIRC_VEHICLE',
                               TO_CHAR (a.contribcircumstancesvehicle));
        ELSE
            tcntrib_circum_descr := NULL;
        END IF;

/*
IF a.contribcircumstancesvehicle IS NOT NULL THEN
  curlen := length(crash_lookupi ('CONTRIB_CIRC_VEHICLE', TO_CHAR (a.contribcircumstancesvehicle)));
ELSE
  curlen := 0;
END IF;
*/
      
--UTL_FILE.PUT_LINE(file_handle,'textent_of_damage_descr');
        IF a.extentofdamage IS NOT NULL
        THEN
            textent_of_damage_descr :=
                crash_lookupi ('EXTENT_OF_DAMAGE',
                               TO_CHAR (a.extentofdamage));
        ELSE
            textent_of_damage_descr := NULL;
        END IF;

/*
IF a.extentofdamage IS NOT NULL THEN
  curlen := length(crash_lookupi ('EXTENT_OF_DAMAGE', TO_CHAR (a.extentofdamage)));
ELSE
  curlen := 0;
END IF;
*/
       
--UTL_FILE.PUT_LINE(file_handle,'tdirection_of_travel_descr');
        IF a.vehicletraveldirection IS NOT NULL
        THEN
            tdirection_of_travel_descr :=
                crash_lookupi ('DIRECTION_OF_TRAVEL',
                               TO_CHAR (a.vehicletraveldirection));
        ELSE
            tdirection_of_travel_descr := NULL;
        END IF;

/*
IF a.vehicletraveldirection IS NOT NULL THEN
  curlen := length(crash_lookupi ('DIRECTION_OF_TRAVEL', TO_CHAR (a.vehicletraveldirection)));
ELSE
  curlen := 0;
END IF;
*/
       
--UTL_FILE.PUT_LINE(file_handle,'temerg_veh_responding_to_call');
        IF    a.emergencyvehrespondingtocall IS NULL
           OR a.emergencyvehrespondingtocall = 0
        THEN
            temerg_veh_responding_to_call := NULL;
        ELSE
            temerg_veh_responding_to_call :=
                crash_lookupi ('YES_NO_UNKOWN',
                               TO_CHAR (a.emergencyvehrespondingtocall));
        END IF;

/*
IF    a.emergencyvehrespondingtocall IS NULL
           OR a.emergencyvehrespondingtocall = 0 THEN
  curlen := 0;
ELSE  
  curlen := length(crash_lookupi ('YES_NO_UNKOWN', TO_CHAR (a.emergencyvehrespondingtocall)));
END IF;
*/
        
--UTL_FILE.PUT_LINE(file_handle,'texempt_vehicle');
        IF a.exemptvehicle IS NULL OR a.exemptvehicle = 0
        THEN
            texempt_vehicle := NULL;
        ELSE
            texempt_vehicle :=
                crash_lookupi ('YES_NO_UNKOWN', TO_CHAR (a.exemptvehicle));
        END IF;
     
/*   
IF    a.exemptvehicle IS NULL
           OR a.exemptvehicle = 0 THEN
  curlen := 0;
ELSE  
  curlen := length(crash_lookupi ('YES_NO_UNKOWN', TO_CHAR (a.exemptvehicle)));
END IF;
*/

--UTL_FILE.PUT_LINE(file_handle,'tgvwr_or_gcwr_descr');
        IF a.gvwrorgcwr IS NOT NULL
        THEN
            tgvwr_or_gcwr_descr :=
                crash_lookupi ('GVWR_GCWR', TO_CHAR (a.gvwrorgcwr));
        ELSE
            tgvwr_or_gcwr_descr := NULL;
        END IF;
  
/*    
IF a.gvwrorgcwr IS NOT NULL THEN
  curlen := length(crash_lookupi ('GVWR_GCWR', TO_CHAR (a.gvwrorgcwr)));
ELSE
  curlen := 0;
END IF;
*/

--UTL_FILE.PUT_LINE(file_handle,'thazmat_placard_descr');
        IF a.hazmatplacarded IS NULL OR a.hazmatplacarded = 0
        THEN
            thazmat_placard_descr := NULL;
        ELSE
            thazmat_placard_descr :=
                crash_lookupi ('YES_NO_UNKOWN', TO_CHAR (a.hazmatplacarded));
        END IF;

/*
IF    a.hazmatplacarded IS NULL
           OR a.hazmatplacarded = 0 THEN
  curlen := 0;
ELSE  
  curlen := length(crash_lookupi ('YES_NO_UNKOWN', TO_CHAR (a.hazmatplacarded)));
END IF; 
*/       
       
--UTL_FILE.PUT_LINE(file_handle,'thit_and_run_descr');
        IF a.hitandrun IS NULL OR a.hitandrun = 0
        THEN
            thit_and_run_descr := NULL;
        ELSE
            thit_and_run_descr :=
                crash_lookupi ('YES_NO_UNKOWN', TO_CHAR (a.hitandrun));
        END IF;
   
/*     
IF    a.hitandrun IS NULL
           OR a.hitandrun = 0 THEN
  curlen := 0;
ELSE  
  curlen := length(crash_lookupi ('YES_NO_UNKOWN', TO_CHAR (a.hitandrun)));
END IF;
*/        
        
--UTL_FILE.PUT_LINE(file_handle,'tlicense_state_descr');  
        IF a.licenseplatestate IS NOT NULL
        THEN
            tlicense_state_descr :=
                crash_lookupi ('LICENSE_STATE',
                               TO_CHAR (a.licenseplatestate));
        ELSE
            tlicense_state_descr := NULL;
        END IF;
   
/*    
IF a.licenseplatestate IS NOT NULL THEN
  curlen := length(crash_lookupi ('LICENSE_STATE', TO_CHAR (a.licenseplatestate)));
ELSE
  curlen := 0;
END IF; 
*/       
        
--UTL_FILE.PUT_LINE(file_handle,'tmost_damaged_area_descr');      
        IF a.mostdamagedarea IS NOT NULL
        THEN
            tmost_damaged_area_descr :=
                crash_lookupi ('DAMAGE_AREA',
                               TO_CHAR (a.mostdamagedarea));
        ELSE
            tmost_damaged_area_descr := NULL;
        END IF;

/*
IF a.mostdamagedarea IS NOT NULL THEN
  curlen := length(crash_lookupi ('DAMAGE_AREA', TO_CHAR (a.mostdamagedarea)));
ELSE
  curlen := 0;
END IF;
*/                
       
--UTL_FILE.PUT_LINE(file_handle,'tmost_harmful_event_descr');
        IF a.mostharmfulevent IS NOT NULL
        THEN
            tmost_harmful_event_descr :=
                crash_lookupi ('MOST_HARMFUL_EVENT',
                               TO_CHAR (a.mostharmfulevent));
        ELSE
            tmost_harmful_event_descr := NULL;
        END IF;

/*
IF a.mostharmfulevent IS NOT NULL THEN
  curlen := length(crash_lookupi ('MOST_HARMFUL_EVENT', TO_CHAR (a.mostharmfulevent)));
ELSE
  curlen := 0;
END IF;
*/                    
      
--UTL_FILE.PUT_LINE(file_handle,'tnine_or_more_seats_descr');
        IF a.vehiclehas9ormoreseats IS NULL OR a.vehiclehas9ormoreseats = 0
        THEN
            tnine_or_more_seats_descr := NULL;
        ELSE
            tnine_or_more_seats_descr :=
                crash_lookupi ('YES_NO_UNKOWN',
                               TO_CHAR (a.vehiclehas9ormoreseats));
        END IF;

/*
IF    a.vehiclehas9ormoreseats IS NULL
           OR a.vehiclehas9ormoreseats = 0 THEN
  curlen := 0;
ELSE  
  curlen := length(crash_lookupi ('YES_NO_UNKOWN', TO_CHAR (a.vehiclehas9ormoreseats)));
END IF;
*/        
        
--UTL_FILE.PUT_LINE(file_handle,'tprecrash_actions_descr');
        IF a.precrashactions IS NOT NULL
        THEN
            tprecrash_actions_descr :=
                crash_lookupi ('PRECRASH_ACTIONS',
                               TO_CHAR (a.precrashactions));
        ELSE
            tprecrash_actions_descr := NULL;
        END IF;

/*
IF a.precrashactions IS NOT NULL THEN
  curlen := length(crash_lookupi ('PRECRASH_ACTIONS', TO_CHAR (a.precrashactions)));
ELSE
  curlen := 0;
END IF;  
*/      
       
--UTL_FILE.PUT_LINE(file_handle,'tseq_of_events1_descr');
        IF a.sequenceofevents1 IS NOT NULL
        THEN
            tseq_of_events1_descr :=
                crash_lookupi ('SEQUENCE_OF_EVENTS_VEHICLE',
                               TO_CHAR (a.sequenceofevents1));
        ELSE
            tseq_of_events1_descr := NULL;
        END IF;

/*
IF a.sequenceofevents4 IS NOT NULL THEN
  curlen := length(crash_lookupi ('SEQUENCE_OF_EVENTS_VEHICLE', TO_CHAR (a.sequenceofevents4)));
ELSE
  curlen := 0;
END IF;  
*/              
        
--UTL_FILE.PUT_LINE(file_handle,'tseq_of_events2_descr');
        IF a.sequenceofevents2 IS NOT NULL
        THEN
            tseq_of_events2_descr :=
                crash_lookupi ('SEQUENCE_OF_EVENTS_VEHICLE',
                               TO_CHAR (a.sequenceofevents2));
        ELSE
            tseq_of_events2_descr := NULL;
        END IF;
--UTL_FILE.PUT_LINE(file_handle,'tseq_of_events3_descr');
        IF a.sequenceofevents3 IS NOT NULL
        THEN
            tseq_of_events3_descr :=
                crash_lookupi ('SEQUENCE_OF_EVENTS_VEHICLE',
                               TO_CHAR (a.sequenceofevents3));
        ELSE
            tseq_of_events3_descr := NULL;
        END IF;
--UTL_FILE.PUT_LINE(file_handle,'tseq_of_events4_descr');
        IF a.sequenceofevents4 IS NOT NULL
        THEN
            tseq_of_events4_descr :=
                crash_lookupi ('SEQUENCE_OF_EVENTS_VEHICLE',
                               TO_CHAR (a.sequenceofevents4));
        ELSE
            tseq_of_events4_descr := NULL;
        END IF;
--UTL_FILE.PUT_LINE(file_handle,'tspecial_func_vehicle_descr');
        IF a.specialfunctionvehicle IS NOT NULL
        THEN
            tspecial_func_vehicle_descr :=
                crash_lookupi ('SPECIAL_FUNCTION_VEHICLE',
                               TO_CHAR (a.specialfunctionvehicle));
        ELSE
            tspecial_func_vehicle_descr := NULL;
        END IF;

/* 
IF a.specialfunctionvehicle IS NOT NULL THEN
  curlen := length(crash_lookupi ('SPECIAL_FUNCTION_VEHICLE', TO_CHAR (a.specialfunctionvehicle)));
ELSE
  curlen := 0;
END IF;    
*/         
       
--UTL_FILE.PUT_LINE(file_handle,'tunit_type_descr');
        IF a.unittype IS NOT NULL
        THEN
            tunit_type_descr :=
                crash_lookupi ('UNIT_TYPE', TO_CHAR (a.unittype));
        ELSE
            tunit_type_descr := NULL;
        END IF;
 
/*    
IF a.unittype IS NOT NULL THEN
  curlen := length(crash_lookupi ('UNIT_TYPE', TO_CHAR (a.unittype)));
ELSE
  curlen := 0;
END IF;
*/            
        
--UTL_FILE.PUT_LINE(file_handle,'tvehicle_color_descr');
        IF a.vehiclecolor IS NOT NULL
        THEN
            tvehicle_color_descr :=
                crash_lookupi ('VEHICLE_COLOR', TO_CHAR (a.vehiclecolor));
        ELSE
            tvehicle_color_descr := NULL;
        END IF;
    
/*   
IF a.vehiclecolor IS NOT NULL THEN
  curlen := length(crash_lookupi ('VEHICLE_COLOR', TO_CHAR (a.vehiclecolor)));
ELSE
  curlen := 0;
END IF; 
*/     
        
--UTL_FILE.PUT_LINE(file_handle,'tvehicle_config_descr');
        IF a.vehicleconfiguration IS NOT NULL
        THEN
            tvehicle_config_descr :=
                crash_lookupi ('VEHICLE_CONFIGURATION',
                               TO_CHAR (a.vehicleconfiguration));
        ELSE
            tvehicle_config_descr := NULL;
        END IF;
/*
IF a.vehicleconfiguration IS NOT NULL THEN
  curlen := length(crash_lookupi ('VEHICLE_CONFIGURATION', TO_CHAR (a.vehicleconfiguration)));
ELSE
  curlen := 0;
END IF;              
*/        
--UTL_FILE.PUT_LINE(file_handle,'tvehicle_make_descr');
        IF a.vehiclemake IS NOT NULL
        THEN
            tvehicle_make_descr :=
                crash_lookupi ('VEHICLE_MAKE', TO_CHAR (a.vehiclemake));
        ELSE
            tvehicle_make_descr := NULL;
        END IF;
/*
IF a.vehiclemake IS NOT NULL THEN
  curlen := length(crash_lookupi ('VEHICLE_MAKE', TO_CHAR (a.vehiclemake)));
ELSE
  curlen := 0;
END IF;              
/*
        INSERT INTO accident_units (accident_year,
                                    automation_levels_engaged,
                                    automation_levels_engaged_descr,
                                    automation_levels_in_vehicle,
                                    automation_levels_in_vehicle_descr,
                                    automation_system_in_vehicle,
                                    cntrib_circum,
                                    cntrib_circum_descr,
                                    crashreportid,
                                    direction_of_travel,
                                    direction_of_travel_descr,
                                    emerg_veh_responding_to_call,
                                    exempt_vehicle,
                                    extent_of_damage,
                                    extent_of_damage_descr,
                                    -- fixed_object_struck_descr,
                                    gvwr_or_gcwr,
                                    gvwr_or_gcwr_descr,
                                    hazmat_placard,
                                    hazmat_placard_descr,
                                    hit_and_run,
                                    hit_and_run_descr,
                                    license_plate_no,
                                    license_state,
                                    license_state_descr,
                                    mdotid,
                                    most_damaged_area,
                                    most_damaged_area_descr,
                                    most_harmful_event,
                                    most_harmful_event_descr,
                                    nine_or_more_seats,
                                    nine_or_more_seats_descr,
                                    precrash_actions,
                                    precrash_actions_descr,
                                    seq_of_events1,
                                    seq_of_events1_descr,
                                    seq_of_events2,
                                    seq_of_events2_descr,
                                    seq_of_events3,
                                    seq_of_events3_descr,
                                    seq_of_events4,
                                    seq_of_events4_descr,
                                    special_func_vehicle,
                                    special_func_vehicle_descr,
                                    unit_id,
                                    unit_type,
                                    unit_type_descr,
                                    vehicle_color,
                                    vehicle_color_descr,
                                    vehicle_config,
                                    vehicle_config_descr,
                                    vehicle_make,
                                    vehicle_make_descr,
                                    vin)
             VALUES (a.accident_year,
                     a.automationlevelsengaged,
                     tautomation_levels_engaged_descr,
                     a.automationlevelsinvehicle,
                     tautomation_levels_in_vehicle_descr,
                     tautomation_system_in_vehicle,
                     a.contribcircumstancesvehicle,
                     tcntrib_circum_descr,
                     a.crashreportid,
                     a.vehicletraveldirection,
                     tdirection_of_travel_descr,
                     temerg_veh_responding_to_call,
                     texempt_vehicle,
                     a.extentofdamage,
                     textent_of_damage_descr,
                     --a.fos_description,
                     a.gvwrorgcwr,
                     tgvwr_or_gcwr_descr,
                     a.hazmatplacarded,
                     thazmat_placard_descr,
                     a.hitandrun,
                     thit_and_run_descr,
                     a.licenseplatenumber,
                     a.licenseplatestate,
                     tlicense_state_descr,
                     a.mdotid,
                     a.mostdamagedarea,
                     tmost_damaged_area_descr,
                     a.mostharmfulevent,
                     tmost_harmful_event_descr,
                     a.vehiclehas9ormoreseats,
                     tnine_or_more_seats_descr,
                     a.precrashactions,
                     tprecrash_actions_descr,
                     a.sequenceofevents1,
                     tseq_of_events1_descr,
                     a.sequenceofevents2,
                     tseq_of_events2_descr,
                     a.sequenceofevents3,
                     tseq_of_events3_descr,
                     a.sequenceofevents4,
                     tseq_of_events4_descr,
                     a.specialfunctionvehicle,
                     tspecial_func_vehicle_descr,
                     a.unitid,
                     a.unittype,
                     tunit_type_descr,
                     a.vehiclecolor,
                     tvehicle_color_descr,
                     a.vehicleconfiguration,
                     tvehicle_config_descr,
                     a.vehiclemake,
                     tvehicle_make_descr,
                     a.vin)
                LOG ERRORS INTO accident_units_error_log
                        ('LOAD ACCIDENT UNITS ' || SYSDATE)
                        REJECT LIMIT 100;
*/
/*
        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
*/        
      if curlen  > maxlen then maxlen := curlen; END IF;
    END LOOP;
/*
    COMMIT;
    --MANAGE_INDEXES.Rebuild_Unusable_Indexes ('ACCIDENT_UNITS');

    SELECT COUNT (*) INTO cntr FROM ACCIDENT_UNITS;

    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
        OWNER         => G_OWNER,
        OBJECT_NAME   => g_object,
        object_cnt    => cntr,
        proc          => $$PLSQL_UNIT,
        start_time    => g_start_time);
        
    UTL_FILE.FCLOSE(file_handle);    
*/  
--dbms_output.put_line('vehiclemake = ' || to_char(maxlen)); 
  
EXCEPTION
    WHEN OTHERS
    THEN
    
    --UTL_FILE.FCLOSE(file_handle);
    
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
/
