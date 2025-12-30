CREATE OR REPLACE PROCEDURE load_traffic_signals
IS
    /**********************************************************************
    This procedure loads the traffic_signals table from the GIS system.

    It truncates the table and re-loads it weekly.

    12-13-21 SH  Initial Version

    **********************************************************************/



    commit_count   NUMBER (7) := 0;
    cntr           NUMBER (7) := 0;

    g_start_time   DATE := SYSDATE;
    g_owner        VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname      VARCHAR2 (30) := 'LOAD_TRAFFIC_SIGNALS';
    g_object       VARCHAR2 (20) := 'TRAFFIC_SIGNALS';
    g_sqlmsg       VARCHAR2 (500) := NULL;



    CURSOR trafs IS
        SELECT asset_sys_id      AS signal_id,
               direction,
               intersection,
               maintained_by,
               meter_number,
               m_snap            AS milepoint,
               nearest_node      AS nearest_node_id,
               rtcode            AS route_number,
               signal_beacon     AS signal_type,
               town_id           AS town_code,
               town_name
          FROM TRAFFIC_SIGNALS@GIS;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE TRAFFIC_SIGNALS';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE TRAFFIC_SIGNALS_ERROR_LOG';



    FOR t IN trafs
    LOOP
        INSERT INTO traffic_signals (direction,
                                     intersection,
                                     maintained_by,
                                     meter_number,
                                     milepoint,
                                     nearest_node_id,
                                     route_number,
                                     signal_id,
                                     signal_type,
                                     town_code,
                                     town_name)
             VALUES (t.direction,
                     t.intersection,
                     t.maintained_by,
                     t.meter_number,
                     t.milepoint,
                     t.nearest_node_id,
                     t.route_number,
                     t.signal_id,
                     t.signal_type,
                     t.town_code,
                     t.town_name)
                LOG ERRORS INTO traffic_signals_error_log
                        ('Load Traffic Signals ' || SYSDATE)
                        REJECT LIMIT 100;


        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;


    SELECT COUNT (*) INTO cntr FROM traffic_signals;



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
/
