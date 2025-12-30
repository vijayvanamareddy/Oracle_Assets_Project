CREATE OR REPLACE PROCEDURE load_accident_damaged_property
IS
    /**********************************************************************
    This procedure loads the ACCIDENT_NONVEHICLE_PROPDAMAGE table from CRASH.

    It truncates the table and re-loads it.

    06-12-2018 SH  Initial Version
    09-19-2019 SH  Add crashreportid and only add crashes in the accidents table in preparation for loading nonvehicle property damage daily
    **********************************************************************/



    commit_count                   NUMBER (7) := 0;
    cntr                           NUMBER (7) := 0;

    g_start_time                   DATE := SYSDATE;
    g_owner                        VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                      VARCHAR2 (30) := 'load_accident_damaged_property';
    g_object                       VARCHAR2 (30) := 'ACCIDENT_NONVEHICLE_PROPDAMAGE';
    g_sqlmsg                       VARCHAR2 (500) := NULL;
    
    tdamage_prop_owner_type_descr  accident_nonvehicle_propdamage.damage_prop_owner_type_descr%TYPE;
    
    CURSOR acc
    IS
        SELECT 
               d.name,
               d.address,
               d.cityortown,
               d.state,
               d.zipcode,
               d.damagedpropertyownertype,
               d.damagedescription,          
               ac.mdotid,
               d.crashreportid
             FROM accidents ac join nonvehiclepropertydamage@crash d
             ON  d.crashreportid = ac.crashreportid ;
           
          
    BEGIN
              
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ACCIDENT_NONVEHICLE_PROPDAMAGE';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE ACCIDENT_NVPD_ERROR_LOG';


    FOR a IN acc
    LOOP
        -- Lookup descriptions
        
    IF a.damagedpropertyownertype IS NOT NULL 
    THEN tdamage_prop_owner_type_descr  :=
            crash_lookupi ('DAMAGED_PROPERTY_OWNER_TYPE' ,TO_CHAR(a.damagedpropertyownertype)) ;
    ELSE tdamage_prop_owner_type_descr  := NULL;
    END IF;
   
 
        INSERT INTO accident_nonvehicle_propdamage 
            (address,
            crashreportid,
            damage_description,
            damage_prop_owner_type,
            damage_prop_owner_type_descr,
            mdotid,
            name,
            state,
            town_name,
            zipcode)
           VALUES (a.address,     
                   a.crashreportid,        
                   a.damagedescription,
                   a.damagedpropertyownertype,
                   tdamage_prop_owner_type_descr,
                   a.mdotid,
                   a.name,
                   a.state,
                   a.cityortown,
                   a.zipcode) 
                LOG ERRORS INTO ACCIDENT_NVPD_ERROR_LOG
                        ('load_accident_damaged_property ' || SYSDATE)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;

select count(*) into cntr from ACCIDENT_NONVEHICLE_PROPDAMAGE;
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
