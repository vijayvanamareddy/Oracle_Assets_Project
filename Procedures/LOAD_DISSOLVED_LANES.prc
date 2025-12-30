CREATE OR REPLACE PROCEDURE load_dissolved_lanes
IS
/**********************************************************************
This procedure uses the dissolve function to create disolved lane data by psn and route number

06-07-21  SH Initial Version
08-24-21  SH Add town_name and streetname to the dissolve
08-25-21  SH Add RIGHT_TURN_LANE_COUNT, RIGHT_TURN_LANE_WIDTH to the dissolve

**********************************************************************/
BEGIN
    DECLARE
      
        g_start_time                  DATE := SYSDATE;
        g_owner                       VARCHAR2 (20) := 'WH_ASSETS';
        g_jobname                     VARCHAR2 (30) := 'LOAD_DISSOLVED_LANES';
        g_object                      VARCHAR2 (20) := 'DISSOLVED_LANES';
        g_sqlmsg                      VARCHAR2 (500) := NULL;

        var_RetVal                    SYS_REFCURSOR;

        l_route_id                    NVARCHAR2 (100);
        l_bmp                         NVARCHAR2 (50);
        l_emp                         NVARCHAR2 (50);
        l_table                       NVARCHAR2 (100);
        l_columns                     NVARCHAR2 (32767);
        l_where                       NVARCHAR2 (32767);


        l_route_number                NVARCHAR2 (100);
        l_route_number_psn            NVARCHAR2 (100);
        l_project_route_number        NVARCHAR2 (100);
        l_begin_section_mp            NUMBER;
        l_end_section_mp              NUMBER;



        l_psn                         NVARCHAR2 (100);
        l_pin                         NVARCHAR2 (100);
        l_median_average_width        NVARCHAR2 (100);
        l_median_type                 NVARCHAR2 (100);
        l_left_shoulder_type_descr    NVARCHAR2 (100);
        l_right_shoulder_type_descr   NVARCHAR2 (100);
        l_left_shoulder_width         NVARCHAR2 (100);
        l_right_shoulder_width        NVARCHAR2 (100);
        l_thru_lane_count             NVARCHAR2 (100);
        l_thru_lane_width             NVARCHAR2 (100);
        l_truck_lane_count            NVARCHAR2 (100);
        l_truck_lane_width            NVARCHAR2 (100);
        l_center_turn_lane_count      NVARCHAR2 (100);
        l_center_turn_lane_width      NVARCHAR2 (100);
        l_left_turn_lane_count        NVARCHAR2 (100);
        l_left_turn_lane_width        NVARCHAR2 (100);
        l_left_lane_crosssection      NVARCHAR2 (100);
        l_right_lane_crosssection     NVARCHAR2 (100);
        l_right_turn_lane_count        NVARCHAR2 (100);
        l_right_turn_lane_width        NVARCHAR2 (100);
        l_town_name                   NVARCHAR2 (100);
        l_streetname                  NVARCHAR2 (100);

        l_begin_element_mp            NUMBER;
        l_start_offset                NUMBER;
        l_end_offset                  NUMBER;

        commit_count                  NUMBER := 0;
        cntr                          NUMBER := 0;

        last_snapshot_year            NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE DISSOLVED_LANES_BY_PSN_ROUTENUM';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE DISSOLVED_LANES_BY_PSN_ROUTENUM_ERROR_LOG';

        -- Initialization

        l_route_id := 'route_number_psn';
        l_bmp := 'begin_section_mp';
        l_emp := 'end_section_mp';
        l_table := 'v_project_locations';

        last_snapshot_year := F_GET_SNAPSHOT_YEAR;

        l_WHERE :=
               'snapshot_year = '
            || last_snapshot_year
            || ' AND  PRIMARY = ''Y'' AND ASSET_TYPE = ''ROAD'' AND transportation_mode = ''HIGHWAY''';

        l_COLUMNS :=
            ' PROJECT_ROUTE_NUMBER, ROUTE_NUMBER, TOWN_NAME, STREETNAME, PSN, PIN, MEDIAN_AVERAGE_WIDTH, MEDIAN_TYPE,LEFT_SHOULDER_TYPE_DESCR, RIGHT_SHOULDER_TYPE_DESCR, LEFT_SHOULDER_WIDTH, RIGHT_SHOULDER_WIDTH, THRU_LANE_COUNT, THRU_LANE_WIDTH	, TRUCK_LANE_COUNT	, TRUCK_LANE_width,
              CENTER_TURN_LANE_COUNT,CENTER_TURN_LANE_WIDTH,LEFT_TURN_LANE_COUNT,LEFT_TURN_LANE_WIDTH, LEFT_LANE_CROSSSECTION, RIGHT_LANE_CROSSSECTION,RIGHT_TURN_LANE_COUNT, RIGHT_TURN_LANE_WIDTH';

        var_RetVal :=
            WH_ASSETS.F_DISSOLVE (l_route_id,
                                  l_bmp,
                                  l_emp,
                                  l_table,
                                  l_columns,
                                  l_where);

        LOOP
            FETCH var_RetVal
                INTO l_route_number_psn,
                     l_begin_section_mp,
                     l_end_section_mp,
                     l_project_route_number,
                     l_route_number,
                     l_town_name,
                     l_streetname,
                     l_psn,
                     l_pin,
                     l_median_average_width,
                     l_median_type,
                     l_left_shoulder_type_descr,
                     l_right_shoulder_type_descr,
                     l_left_shoulder_width,
                     l_right_shoulder_width,
                     l_thru_lane_count,
                     l_thru_lane_width,
                     l_truck_lane_count,
                     l_truck_lane_width,
                     l_center_turn_lane_count,
                     l_center_turn_lane_width,
                     l_left_turn_lane_count,
                     l_left_turn_lane_width,
                     l_left_lane_crosssection,
                     l_right_lane_crosssection,
                     l_right_turn_lane_count,
                     l_right_turn_lane_width;


            EXIT WHEN var_RetVal%NOTFOUND;

            INSERT INTO dissolved_lanes_by_psn_routenum (
                            project_route_number,
                            route_number,
                            town_name,
                            streetname,
                            psn,
                            pin,
                            median_average_width,
                            median_type,
                            left_shoulder_type_descr,
                            right_shoulder_type_descr,
                            left_shoulder_width,
                            right_shoulder_width,
                            thru_lane_count,
                            thru_lane_width,
                            truck_lane_count,
                            truck_lane_width,
                            center_turn_lane_count,
                            center_turn_lane_width,
                            left_turn_lane_count,
                            left_turn_lane_width,
                            left_lane_crosssection,
                            right_lane_crosssection,
                            right_turn_lane_count,
                            right_turn_lane_width,
                            begin_mp,
                            end_mp)
                 VALUES (l_project_route_number,
                         l_route_number,
                         l_town_name,
                         l_streetname,
                         l_psn,
                         l_pin,
                         l_median_average_width,
                         l_median_type,
                         l_left_shoulder_type_descr,
                         l_right_shoulder_type_descr,
                         l_left_shoulder_width,
                         l_right_shoulder_width,
                         l_thru_lane_count,
                         l_thru_lane_width,
                         l_truck_lane_count,
                         l_truck_lane_width,
                         l_center_turn_lane_count,
                         l_center_turn_lane_width,
                         l_left_turn_lane_count,
                         l_left_turn_lane_width,
                         l_left_lane_crosssection,
                         l_right_lane_crosssection,
                         l_right_turn_lane_count,
                         l_right_turn_lane_width,
                         l_begin_section_mp,
                         l_end_section_mp)
                    LOG ERRORS INTO DISSOLVED_LANES_BY_PSN_ROUTENUM_ERROR_LOG
                            ('Load dissolved_lanes ' || SYSDATE)
                            REJECT LIMIT 100;


            commit_count := commit_count + 1;

            IF commit_count > 10000
            THEN
                COMMIT;
                commit_count := 0;
            END IF;
        END LOOP;

        COMMIT;
  
           SELECT COUNT (*) INTO cntr from DISSOLVED_LANES_BY_PSN_ROUTENUM;

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
