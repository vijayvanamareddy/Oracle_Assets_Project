CREATE OR REPLACE PROCEDURE load_highway_maint_work
IS
    /**********************************************************************
    This procedure loads the MAINT_WORK_LOCATIONS table with highway work from Mats.
    
    06-16-22 SH Initial version (redo )
    Loaded all routes for 2015
    Activities for Surface and base maintenance
    08-02-22 SH Add in last 3 years
              Jan - Mar 2020, Apr 2020 - July 2020, August 2020-Dec 2020, August 2021-Dec 2021, Jan - Mar 2021,Apr 2021 - July 2021,
             Jan - Mar 2022, Apr 2022 - July 2022,
    09-30-22 SH Drop column WIN, rename procedure to load_highway_maint_work (dotdw-699)
    **********************************************************************/
    date1                   DATE := TO_DATE('01/01/2022 00:00:00', 'MM/DD/YYYY HH24:MI:SS');
    date2                   DATE := TO_DATE('03/31/2022 00:00:00', 'MM/DD/YYYY HH24:MI:SS');
    
    CURSOR wrk
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
                 rs.element_id               ,
                 rs.section_id           ,
                 rs.begin_section_mp,
                 rs.end_section_mp,
                 rs.town,
                 SUBSTR (rd.descr, 1, 14) route_direction
            FROM daily_work_report@mats  d,
                 work_report_asset@mats  w,
                 route@mats              r,
                 route_direction@mats    rd,
                 txn_wr@mats             wr,
                 activity@mats           a,
                 asset_group@mats        asg,
                 route_sections       rs
           WHERE     d.dwr_sys_id = w.dwr_sys_id
                 AND w.rte_id = r.rte_id
                 AND w.route_direction_sys_id = rd.route_direction_sys_id
                 AND r.display_code = rs.route_number
                 AND d.act_id = a.act_id
                 AND a.display_code in ('102','104','111','112','113','117','131','132','121')
                 AND d.txn_wr_sys_id = wr.txn_wr_sys_id(+)
                 AND w.asset_grp_sys_id = ASG.ASSET_GRP_SYS_ID
                 AND w.asset_grp_sys_id <> 27                  -- not a bridge
                 AND d.dwr_date BETWEEN date1 AND date2
                 AND w.begin_mm_num < rs.end_section_mp
                 AND w.end_mm_num > rs.begin_section_mp;
                 
                      



    cntr                     NUMBER := 0;
    cntr_added              NUMBER := 0;
   
    commit_count            NUMBER := 0;

    g_start_time            DATE := SYSDATE;
    g_owner                 VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname               VARCHAR2 (30) := 'LOAD_HIGHWAY_MAINT_WORK';
    g_object                VARCHAR2 (20) := 'MAINT_WORK_LOCATIONS';
    g_sqlmsg                VARCHAR2 (500) := NULL;
    


BEGIN

 EXECUTE IMMEDIATE 'TRUNCATE TABLE MAINT_WORK_LOC_ERROR_LOG';
 MANAGE_INDEXES.Mark_Indexes_Unusable ('MAINT_WORK_LOCATIONS');

 
      
    FOR w IN wrk
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
             w.route_name,                            --    ASSET_NAME
             w.route_number,                       --    ASSET_NUMBER
             w.asset_type,                            --    ASSET_TYPE
             W.work_start_mp,
             W.DWR_DATE,
            W.DWR_SYS_ID,
            W.ELEMENT_ID,
            W.work_end_mp,                  -- END_WORK_MP,
            W.ROUTE_DIRECTION,
            W.ROUTE_NUMBER,
            W.BEGIN_SECTION_MP,
            W.END_SECTION_MP,
            W.SECTION_ID,
            W.TOWN,
            W.WORK_REQUEST_ID)
              LOG ERRORS INTO MAINT_WORK_LOC_ERROR_LOG
                        ('Load Maintenance Work ' || SYSDATE)
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
