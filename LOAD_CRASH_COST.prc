CREATE OR REPLACE PROCEDURE load_crash_cost
IS
    /**********************************************************************
    This procedure calculates the crash_cost and updates the accidents table 
    with the cost.

    It is run after the load_accidents and load_accident_units procedures

    07-27-17 SH  Initial Version
    08-17-17 SH add standard error handling, run weekly in assets_cycle
    08-22-17 SH don't write the case of an accident with witnesses but no units (vehicles) to the data exception table
    09-05-17 SH use NVL function to account for missing unit_type
    10-08-18 SH Update crash_cost for accidents2 table (complete network), comment out accidents for this run.
    11-27-18 SH Cleanup:  Remove reference to accidents2 as everything has been renamed
    **********************************************************************/

    commit_count                     NUMBER (7) := 0;
    cntr                             NUMBER (7) := 0;

    g_start_time                     DATE := SYSDATE;
    g_owner                          VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                        VARCHAR2 (30) := 'LOAD_CRASH_COST';
    g_object                         VARCHAR2 (20) := 'ACCIDENTS';
    g_sqlmsg                         VARCHAR2 (500) := NULL;
    err                              VARCHAR2 (100);
    
    num_crash_units                  NUMBER;  
    num_witnesses                    NUMBER; 
    tcrash_cost                      NUMBER;
    
    ta_cost crash_cost.a_inj%TYPE;
    tb_cost crash_cost.b_inj%TYPE;
    tc_cost crash_cost.c_inj%TYPE;
    tk_cost crash_cost.k_inj%TYPE;
    tunit_cost crash_cost.unit_cost%TYPE;
    
    CURSOR acc IS 
    SELECT location_type,mdotid,node_id,no_of_a_inj,no_of_b_inj,no_of_c_inj,no_of_k_inj,offset
    FROM accidents;
           
 
BEGIN
 

    SELECT a_inj,b_inj,c_inj,k_inj,unit_cost INTO ta_cost,tb_cost,tc_cost,tk_cost,tunit_cost FROM crash_cost;

    FOR a IN acc
    LOOP
       SELECT COUNT(*) INTO num_crash_units FROM ACCIDENT_UNITS  WHERE mdotid = a.mdotid AND NVL(unit_type,0) <> 24;  -- exclude 'WITNESS'
       SELECT COUNT(*) INTO num_witnesses FROM ACCIDENT_UNITS  WHERE mdotid = a.mdotid AND NVL(unit_type,0) = 24; 
       IF num_crash_units = 0 AND num_witnesses = 0
       THEN 
          err := 'Missing unit (vehicle)';
          INSERT INTO data_exceptions (table_name,
                                         error_condition,
                                         test_procedure,
                                         test_date,
                                         assessment,
                                         column_name1,
                                         column_value1
                                         )
                 VALUES ('ACCIDENT_UNITS',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'QUALITY',
                         'MDOTID',
                         a.mdotid);
       END IF;
      
        tcrash_cost := (a.no_of_a_inj * ta_cost) + (a.no_of_b_inj * tb_cost) + (a.no_of_c_inj * tc_cost) + (a.no_of_k_inj * tk_cost) + (num_crash_units * tunit_cost);
       
                UPDATE accidents
                SET crash_cost = tcrash_cost
                WHERE mdotid = a.mdotid
                LOG ERRORS INTO accidents_error_log
                        ('Load Crash Cost ' || SYSDATE)
                        REJECT LIMIT 100;
                      

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;

select count(*) into cntr from ACCIDENTS;
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
