CREATE OR REPLACE PROCEDURE load_large_culverts_maint_work
IS
    /**********************************************************************
    This procedure loads the MAINT_WORK_LOCATIONS table with work on large culverts from Mats.

   12-20-2022 SH Initial version 
   06-30-2023 SH Bring maintenance work up to the current network to match project locations
              delete existing rows
    **********************************************************************/


    CURSOR lc_wrk IS
        SELECT d.dwr_sys_id,
               d.dwr_date,
               a.display_code               activity,
               wr.txn_wr_sys_id             work_request_id,
               asg.descr                    Asset_type,
               r.display_code               Route_Number,
               r.route_name,
               w.begin_mm_num               work_start_mp,
               w.end_mm_num                 work_end_mp,
               lc.ELEMENT_ID,
               lc.section_id,
               rs.begin_section_mp,
               rs.end_section_mp,
               lc.town,
               SUBSTR (rd.descr, 1, 14)     route_direction,
               lc.culvert_element_id        asset_name,
               lc.asset_sys_id              Asset_number
          FROM daily_work_report@mats  d,
               work_report_asset@mats  w,
               route@mats              r,
               route_direction@mats    rd,
               txn_wr@mats             wr,
               activity@mats           a,
               asset_group@mats        asg,
               route_sections          rs,
               large_culverts          lc
         WHERE     d.dwr_sys_id = w.dwr_sys_id
               AND w.rte_id = r.rte_id
               AND w.route_direction_sys_id = rd.route_direction_sys_id
               AND r.display_code = rs.route_number
               AND d.act_id = a.act_id
               AND d.txn_wr_sys_id = wr.txn_wr_sys_id(+)
               AND w.asset_grp_sys_id = 115                   -- large culvert
               AND w.asset_grp_sys_id = ASG.ASSET_GRP_SYS_ID
               AND w.ASSET_SYS_ID = lc.ASSET_SYS_ID
               AND rs.section_id = lc.section_id;



    cntr              NUMBER := 0;
    cntr_added        NUMBER := 0;
    errlog_count      NUMBER := 0;
    err_log_message   VARCHAR2 (200);


    commit_count      NUMBER := 0;

    g_start_time      DATE := SYSDATE;
    g_owner           VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname         VARCHAR2 (30) := 'LOAD_LARGE_CULVERTS_MAINT_WORK';
    g_object          VARCHAR2 (20) := 'MAINT_WORK_LOCATIONS';
    g_sqlmsg          VARCHAR2 (500) := NULL;
BEGIN
  
        EXECUTE IMMEDIATE 'TRUNCATE TABLE MAINT_WORK_LOC_ERROR_LOG';
   

    DELETE FROM maint_work_locations
          WHERE asset_type = 'Large Culvert';

    COMMIT;


    FOR w IN lc_wrk
    LOOP
        INSERT /*+ APPEND */
               INTO MAINT_WORK_LOCATIONS (ACTIVITY,
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
                     W.ASSET_NAME,                            --    ASSET_NAME
                     W.ASSET_NUMBER,                        --    ASSET_NUMBER
                     W.ASSET_TYPE,                            --    ASSET_TYPE
                     W.WORK_START_MP,
                     W.DWR_DATE,
                     W.DWR_SYS_ID,
                     W.ELEMENT_ID,
                     W.WORK_END_MP,                            -- END_WORK_MP,
                     W.ROUTE_DIRECTION,
                     W.ROUTE_NUMBER,
                     W.BEGIN_SECTION_MP,
                     W.END_SECTION_MP,
                     W.SECTION_ID,
                     W.TOWN,
                     W.WORK_REQUEST_ID)
                LOG ERRORS INTO MAINT_WORK_LOC_ERROR_LOG
                        ('Load Large Culvert Maintenance Work ' || SYSDATE)
                        REJECT LIMIT 100;


        cntr_added := cntr_added + 1;
        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;


    COMMIT;

    -- Check error logs for quality errors


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
                         'LOAD_LARGE_CULVERTS_MAINT_WORK',
                         'WH_ASSETS',
                         err_log_message);

            COMMIT;
        END;
    END IF;


    SELECT COUNT (*) INTO cntr FROM MAINT_WORK_LOCATIONS;

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
