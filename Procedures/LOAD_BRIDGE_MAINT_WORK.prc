CREATE OR REPLACE PROCEDURE load_bridge_maint_work
IS
    /**********************************************************************
    This procedure loads the MAINT_WORK_LOCATIONS table with bridge work from Mats.
    
   
   06-30-2023 SH Bring maintenance work up to the current network to match project locations
              delete existing rows
    **********************************************************************/
    
    CURSOR brdg_wrk
    IS
          SELECT d.dwr_sys_id,
                 d.dwr_date,               
                 a.display_code           activity,
                 wr.txn_wr_sys_id         work_request_id,
                 asg.descr                Asset_type,
                 r.display_code           Route_Number,
                 r.route_name,
                 w.begin_mm_num           work_start_mp,
                 w.end_mm_num             work_end_mp,
                 b.ELEMENT_ID_ON_STRUCTURE              ,
                 b.section_id           ,
                rs.begin_section_mp,
                rs.end_section_mp,
                 b.town_name1,
                 SUBSTR (rd.descr, 1, 14) route_direction,
                 SUBSTR (ass.display_code, 4, 4)               Asset_number,
                 b.bridge_name        Asset_name
            FROM daily_work_report@mats  d,
                 work_report_asset@mats  w,
                 route@mats              r,
                 route_direction@mats    rd,
                 txn_wr@mats             wr,
                 activity@mats           a,
                 asset_group@mats        asg,
                 asset@mats              ass,
                route_sections       rs,
                 ibridges b
           WHERE     d.dwr_sys_id = w.dwr_sys_id
                 AND w.rte_id = r.rte_id
                 AND w.route_direction_sys_id = rd.route_direction_sys_id
                AND r.display_code = rs.route_number
                 AND d.act_id = a.act_id
                 AND d.txn_wr_sys_id = wr.txn_wr_sys_id(+)
                 AND w.asset_grp_sys_id = ASG.ASSET_GRP_SYS_ID
                 AND w.asset_grp_sys_id = 27                  --  bridge
                  AND w.asset_sys_id = ass.asset_sys_id
                  and b.bridge_number = SUBSTR (ass.display_code, 4, 4)
                 AND rs.section_id = b.section_id order by asset_number,dwr_date;



    cntr                     NUMBER := 0;
    cntr_added              NUMBER := 0;
   
    commit_count            NUMBER := 0;

    g_start_time            DATE := SYSDATE;
    g_owner                 VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname               VARCHAR2 (30) := 'LOAD_BRIDGE_MAINT_WORK';
    g_object                VARCHAR2 (20) := 'MAINT_WORK_LOCATIONS';
    g_sqlmsg                VARCHAR2 (500) := NULL;
    errlog_count      NUMBER := 0;
    err_log_message   VARCHAR2 (200);



BEGIN

 
 EXECUTE IMMEDIATE 'TRUNCATE TABLE MAINT_WORK_LOC_ERROR_LOG';

 MANAGE_INDEXES.Mark_Indexes_Unusable ('MAINT_WORK_LOCATIONS');

 delete from maint_work_locations where asset_type = 'Bridge';
   COMMIT;
      
    FOR w IN brdg_wrk
    LOOP

        INSERT  /*+ APPEND */ INTO MAINT_WORK_LOCATIONS
            (ACTIVITY,
            ASSET_NAME,
            ASSET_NUMBER,
            ASSET_TYPE,
            BEGIN_WORK_MP,
            DWR_DATE,
            DWR_SYS_ID,
            ELEMENT_ID,
            END_WORK_MP,
            ROUTE_DIRECTION,
            ROUTE_NUMBER,
            SECTION_BMP,
            SECTION_EMP,
            SECTION_ID,
            TOWN,
            WORK_REQUEST_ID)
     VALUES (W.ACTIVITY,
             w.asset_name,                            --    ASSET_NAME
             w.asset_number,                       --    ASSET_NUMBER
             w.asset_type,                            --    ASSET_TYPE
             W.work_start_mp,
             W.DWR_DATE,
            W.DWR_SYS_ID,
            W.ELEMENT_ID_ON_STRUCTURE,
            W.work_end_mp,                  -- END_WORK_MP,
            W.ROUTE_DIRECTION,
            W.ROUTE_NUMBER,
            W.BEGIN_SECTION_MP,
            W.END_SECTION_MP,
            W.SECTION_ID,
            W.town_name1,
            W.WORK_REQUEST_ID)
              LOG ERRORS INTO MAINT_WORK_LOC_ERROR_LOG
                        ('Load Bridge Maintenance Work ' || SYSDATE)
                        REJECT LIMIT 100;

   
  cntr_added   := cntr_added + 1;  
  commit_count := commit_count + 1;

      IF commit_count > 10000
      THEN
         COMMIT;
         commit_count := 0;
      END IF;

 END LOOP;
    

    COMMIT;

   MANAGE_INDEXES.Rebuild_Unusable_Indexes ('MAINT_WORK_LOCATIONS');
   
   -- Check error log
   
    SELECT COUNT (*) INTO errlog_count FROM MAINT_WORK_LOC_ERROR_LOG;

    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in maint_work_loc_error_log';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'LOAD_BRIDGE_MAINT_WORK',
                         'WH_ASSETS',
                         err_log_message);

            COMMIT;
        END;
    END IF;

   
             SELECT COUNT (*) INTO cntr from MAINT_WORK_LOCATIONS;

       WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
           owner         => g_owner,
           object_name   => g_object,
           object_cnt    => cntr,
           add_cnt       => cntr_added,
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
/
