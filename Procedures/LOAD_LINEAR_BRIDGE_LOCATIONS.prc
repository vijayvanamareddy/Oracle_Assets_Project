CREATE OR REPLACE PROCEDURE load_linear_bridge_locations
IS
    /**********************************************************************
    05-05-2023 SH Initial Version

               Load elements and sections into linear_bridge_locations table
               This table can be used to join to the complete_transportation_network via section_id to
               get information about the highway, rail, or trail
               
               Compute the begin/end milepoints of a bridge within a route 

               Jira Task DOTDW-725
    03-21-24  SH Add snapshot year, added 2023 locations, change truncate to delete for current year
    **********************************************************************/



    
    cntr                     NUMBER := 0;
    cntr_added               NUMBER := 0;
    g_start_time             DATE := SYSDATE;
    g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                VARCHAR2 (30) := 'LOAD_LINEAR_BRIDGE_LOCATIONS';
    g_object                 VARCHAR2 (30) := 'LINEAR_BRIDGE_LOCATIONS';
    g_sqlmsg                 VARCHAR2 (500) := NULL;
    V_flat_file_counts_txt   VARCHAR2 (1000) := NULL;
    errlog_count             NUMBER;
    err_log_message          VARCHAR2 (200) := NULL;
    current_snapshot_yr              NUMBER;


    CURSOR lbridge_sections IS
        SELECT DISTINCT lb.bridge_number,
                        ctn.section_id,
                        ctn.element_id,
                        ctn.begin_section_offset,
                        ctn.end_section_offset,
                        ctn.begin_section_mp,
                        ctn.end_section_mp,
                        lb.route_number
          FROM ibridges  br
               JOIN V_WH_BASE_SECTIONS_NO_XSP@gis lb
                   ON br.bridge_number = lb.bridge_number
               JOIN complete_transportation_network ctn
                   ON     lb.route_number = ctn.route_number
                      AND ctn.begin_section_mp >= lb.begin_section_mp
                      AND ctn.end_section_mp <= lb.end_section_mp
                         where row_type = 'Element'
                     and snapshot_year = current_snapshot_yr;
                                          

    CURSOR end_points IS
          SELECT bridge_number,
                 b.route_number,
                 MIN (begin_section_mp)     begin_point,
                 MAX (end_section_mp)       end_point
            FROM linear_bridge_locations b
        GROUP BY b.bridge_number, b.route_number;
BEGIN


    EXECUTE IMMEDIATE 'TRUNCATE TABLE LINEAR_BRIDGE_ERROR_LOG';
    current_snapshot_yr := F_Get_snapshot_year;
    delete from linear_bridge_locations where snapshot_year = current_snapshot_yr;
    commit;

    FOR lb IN lbridge_sections
    LOOP
        INSERT INTO LINEAR_BRIDGE_LOCATIONS (BRIDGE_NUMBER,
                                             BEGIN_SECTION_MP,
                                             ELEMENT_ID,
                                             END_SECTION_MP,
                                             ROUTE_NUMBER,
                                             SECTION_ID,
                                             SNAPSHOT_YEAR)
             VALUES (lb.BRIDGE_NUMBER,
                     lb.BEGIN_SECTION_MP,
                     lb.ELEMENT_ID,
                     lb.END_SECTION_MP,
                     lb.ROUTE_NUMBER,
                     lb.SECTION_ID,
                   current_snapshot_yr)
                LOG ERRORS INTO LINEAR_BRIDGE_ERROR_LOG
                        ('load_linear_bridges INSERT' || SYSDATE)
                        REJECT LIMIT 100;
          cntr_added := cntr_added + 1;
    END LOOP;

    COMMIT;

    FOR e IN end_points
    LOOP
        UPDATE linear_bridge_locations lbl
           SET begin_bridge_mp = e.begin_point, end_bridge_mp = e.end_point
         WHERE     lbl.BRIDGE_NUMBER = e.bridge_number
               AND lbl.ROUTE_NUMBER = e.route_number
           LOG ERRORS INTO LINEAR_BRIDGE_ERROR_LOG
                   ('load_linear_bridges UPDATE ' || SYSDATE)
                   REJECT LIMIT 100;
    END LOOP;

    COMMIT;

    SELECT COUNT (*) INTO errlog_count FROM LINEAR_BRIDGE_ERROR_LOG;

    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in linear bridge error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'LOAD_LINEAR_BRIDGE_LOCATIONS',
                         'WH_ASSETS',
                         err_log_message);

            COMMIT;
            wh_common.pkg_common_utilities.exit_and_report ($$PLSQL_UNIT,
                                                            'FAILURE',
                                                            err_log_message);
            RAISE_APPLICATION_ERROR (-20010,
                                     $$PLSQL_UNIT || ' ' || err_log_message);
        END;
    ELSE                                                     -- Successful Run
        BEGIN
            SELECT COUNT (*) INTO cntr FROM LINEAR_BRIDGE_LOCATIONS;

            WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
                OWNER         => G_OWNER,
                OBJECT_NAME   => g_object,
                object_cnt    => cntr,
                add_cnt       => cntr_added,
                update_cnt    => 0,
                proc          => $$PLSQL_UNIT,
                start_time    => g_start_time);

            WH_COMMON.PKG_COMMON_UTILITIES.EXIT_AND_REPORT (
                g_jobname,
                'NORMAL',
                V_flat_file_counts_txt);
        END;
    END IF;
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
