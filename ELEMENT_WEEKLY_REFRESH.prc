CREATE OR REPLACE PROCEDURE element_weekly_refresh (
    staging_already_loaded   IN VARCHAR2 := 'N',
    cntr_threshold           IN NUMBER := 3000000)
IS
    /**********************************************************************
    This procedure loads the element_staging table & compares it to the element_history table
    for the weekly refresh.  New elements are added.  Old elements are 'RETIRED'.

    Changed elements cause the current highway row to be updated with the new values.

    03-13-2015 SH - Modified original update_highways procedure to overwrite current highway rows rather than create a new row
    03-17-2015 SH - Added run of highways_diff procedure to log changes to existing rows
    03-21-2015 SH - Run as a weekly scheduled job
    03-23-2015 SH - Truncate element_error_log prior to loading staging table
    04-25-2017 SH - Log errors written by Oracle to error log in data exceptions table rather than aborting refresh process
    03-20-2018 SH - Add elements from ferry,rail, and trail routes.  Rename to ELEMENT_WEEKLY_REFRESH 
    04-23-2018 SH - Add route_type from dim_routes
    07-31-2018 SH - Rename highway_id to element_wid (element warehouse_id) as the network contains more than highways   
                    Rename ROUTE_SYSTEM to ROUTE_GROUP
                    Rename ROUTE_SYSTEM_DESCR to ROUTE_SYSTEM
    05-28-2020 SH - Rename column number_of_lanes to number_of_lane_xsections (Tom Marcotte request)
                   The number of lanes can be obtained from the section level column lane_count
                 - Add Column GA_TYPE and GA_TYPE_DESCR (Ed Beckworth request)
    **********************************************************************/


    CURSOR changes
    IS
        SELECT element_id,
               begin_node_id,
               end_node_id,
               begin_node_description,
               end_node_description,
               route_group,
               route_system,
               element_length,
               existing,
               ga_type,
               ga_type_descr,
               one_way,
               one_way_descr,
               ramp,
               ramp_descr,
               directional_suffix,
               number_of_lane_xsections,
               region,
               town_code,
               county_code,
               county_name,
               town,
               region_descr,
               primary_route_number,
               primary_route_name,
               official_miles,
               route_type,
               factor_group
          FROM element_staging
        MINUS
        SELECT element_id,
               begin_node_id,
               end_node_id,
               begin_node_description,
               end_node_description,
               route_group,
               route_system,
               element_length,
               existing,
               ga_type,
               ga_type_descr,
               one_way,
               one_way_descr,
               ramp,
               ramp_descr,
               directional_suffix,
               number_of_lane_xsections,
               region,
               town_code,
               county_code,
               county_name,
               town,
               region_descr,
               primary_route_number,
               primary_route_name,
               official_miles,
               route_type,
               factor_group
          FROM element_history
         WHERE end_date IS NULL;

    CURSOR retired_element_list
    IS
        SELECT element_id
          FROM element_history
         WHERE end_date IS NULL
        MINUS
        SELECT element_id FROM element_staging;

    cntr_retired               NUMBER (9) := 0;
    cntr                       NUMBER (9) := 0;
    threshold_message          VARCHAR2 (200) := NULL;
    cntr_updated               NUMBER (9) := 0;
    cntr_added                 NUMBER (9) := 0;
    g_owner                    VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                  VARCHAR2 (30) := 'ELEMENT_WEEKLY_REFRESH';
    g_object                   VARCHAR2 (20) := 'ELEMENT_HISTORY';
    g_sqlmsg                   VARCHAR2 (500) := NULL;
    V_flat_file_counts_txt     VARCHAR2 (1000) := NULL;
    initial_number_lanes       NUMBER (5) := 0;
    current_element_wid         NUMBER;
    current_begin_node_descr   VARCHAR2 (200) := NULL;
    current_end_node_descr     VARCHAR2 (200) := NULL;
    g_start_time               DATE := SYSDATE;
    surrogate_key              NUMBER;
    current_year               NUMBER;
    errlog_count               NUMBER;
    err_log_message            VARCHAR2 (200) := NULL;
BEGIN
    SELECT MAX (SNAPSHOT_YEAR)
      INTO current_year
      FROM element_history
     WHERE STATE = 'CURRENT';

    IF staging_already_loaded = 'N'
    THEN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE element_error_log';

        load_element_staging;
        element_diffs;
    END IF;


    FOR rec IN changes
    LOOP
        cntr := cntr + 1;
    END LOOP;

    IF cntr < cntr_threshold
    THEN
        FOR rec IN changes
        LOOP
            SELECT COUNT (*)
              INTO cntr
              FROM element_history
             WHERE element_id = rec.element_id AND end_date IS NULL;

            IF cntr > 0
            THEN -- update the existing element that has some attributes that have changed
                BEGIN
                    UPDATE element_history
                       SET date_modified = g_start_time,
                           modified_by = 'ELEMENT WEEKLY REFRESH',
                           begin_node_id = rec.begin_node_id,
                           begin_node_description =
                               rec.begin_node_description,
                           end_node_id = rec.end_node_id,
                           end_node_description = rec.end_node_description,
                           route_group = rec.route_group,
                           route_system = rec.route_system,
                           element_length = rec.element_length,
                           existing = rec.existing,
                           ga_type = rec.ga_type,
                           ga_type_descr = rec.ga_type_descr,
                           one_way = rec.one_way,
                           one_way_descr = rec.one_way_descr,
                           ramp = rec.ramp,
                           ramp_descr = rec.ramp_descr,
                           directional_suffix = rec.directional_suffix,
                           number_of_lane_xsections = rec.number_of_lane_xsections,
                           region = rec.region,
                           town_code = rec.town_code,
                           county_code = rec.county_code,
                           county_name = rec.county_name,
                           town = rec.town,
                           region_descr = rec.region_descr,
                           primary_route_number = rec.primary_route_number,
                           primary_route_name = rec.primary_route_name,
                           official_miles = rec.official_miles,
                           route_type = rec.route_type,
                           factor_group = rec.factor_group
                     WHERE element_id = rec.element_id AND end_date IS NULL
                       LOG ERRORS INTO element_error_log
                               (   'Element Weekly Refresh - Update Element: '
                                || SYSDATE)
                               REJECT LIMIT 100;

                    cntr_updated := cntr_updated + 1;
                END;
            ELSE                 -- add a new element not yet in the data mart
                BEGIN
                    cntr_added := cntr_added + 1;

                    SELECT assets_sequence.NEXTVAL
                      INTO surrogate_key
                      FROM DUAL;

                    INSERT INTO element_history (element_wid,
                                                  date_created,
                                                  start_date,
                                                  created_by,
                                                  element_id,
                                                  begin_node_id,
                                                  begin_node_description,
                                                  end_node_id,
                                                  end_node_description,
                                                  route_group,
                                                  route_system,
                                                  element_length,
                                                  existing,
                                                  ga_type,
                                                  ga_type_descr,
                                                  one_way,
                                                  one_way_descr,
                                                  ramp,
                                                  ramp_descr,
                                                  directional_suffix,
                                                  number_of_lane_xsections,
                                                  region,
                                                  town_code,
                                                  county_code,
                                                  county_name,
                                                  town,
                                                  region_descr,
                                                  primary_route_number,
                                                  primary_route_name,
                                                  official_miles,
                                                  route_type,
                                                  factor_group,
                                                  snapshot_year,
                                                  state)
                             VALUES (surrogate_key,
                                     g_start_time,
                                     g_start_time,
                                     'ELEMENT WEEKLY REFRESH',
                                     rec.element_id,
                                     rec.begin_node_id,
                                     rec.begin_node_description,
                                     rec.end_node_id,
                                     rec.end_node_description,
                                     rec.route_group,
                                     rec.route_system,
                                     rec.element_length,
                                     rec.existing,
                                     rec.ga_type,
                                     rec.ga_type_descr,
                                     rec.one_way,
                                     rec.one_way_descr,
                                     rec.ramp,
                                     rec.ramp_descr,
                                     rec.directional_suffix,
                                     rec.number_of_lane_xsections,
                                     rec.region,
                                     rec.town_code,
                                     rec.county_code,
                                     rec.county_name,
                                     rec.town,
                                     rec.region_descr,
                                     rec.primary_route_number,
                                     rec.primary_route_name,
                                     rec.official_miles,
                                     rec.route_type,
                                     rec.factor_group,
                                     current_year,
                                     'CURRENT')
                            LOG ERRORS INTO element_error_log
                                    (   'Element Weekly Refresh - Insert Element: '
                                     || SYSDATE)
                                    REJECT LIMIT 100;

                    INSERT INTO element_change_table            -- log insert
                                                      (element_wid,
                                                       element_id,
                                                       change_type,
                                                       change_date,
                                                       column_name,
                                                       table_name,
                                                       modified_by,
                                                       old_value,
                                                       new_value)
                         VALUES (surrogate_key,
                                 rec.element_id,
                                 'I',
                                 g_start_time,
                                 NULL,
                                 g_object,
                                 $$PLSQL_UNIT,
                                 NULL,
                                 NULL);
                END;
            END IF;
        END LOOP;


        FOR rec IN retired_element_list -- elements that have been end-dated in metrans
        LOOP
            BEGIN
                SELECT element_wid
                  INTO surrogate_key
                  FROM element_history
                 WHERE element_id = rec.element_id AND end_date IS NULL;

                UPDATE element_history
                   SET end_date = g_start_time,
                       date_modified = g_start_time,
                       state = 'RETIRED'
                 WHERE element_id = rec.element_id AND end_date IS NULL;

                cntr_retired := cntr_retired + 1;
                cntr_updated := cntr_updated + 1;

                INSERT INTO element_change_table                -- log delete
                                                  (element_wid,
                                                   element_id,
                                                   change_type,
                                                   change_date,
                                                   column_name,
                                                   table_name,
                                                   modified_by,
                                                   old_value,
                                                   new_value)
                     VALUES (surrogate_key,
                             rec.element_id,
                             'D',
                             g_start_time,
                             NULL,
                             g_object,
                             $$PLSQL_UNIT,
                             NULL,
                             NULL);
            END;
        END LOOP;

        COMMIT;

        SELECT COUNT (*) INTO cntr FROM element_history;

        V_flat_file_counts_txt :=
               'ELEMENT_HISTORY: '
            || 'Total Rows: '
            || cntr
            || ' Added: '
            || cntr_added
            || ' Updated/New Row Added: '
            || cntr_updated
            || ' Retired:  '
            || cntr_retired;

        WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
            OWNER         => G_OWNER,
            OBJECT_NAME   => g_object,
            object_cnt    => cntr,
            add_cnt       => cntr_added,
            update_cnt    => cntr_updated,
            proc          => $$PLSQL_UNIT,
            start_time    => g_start_time);

        wh_common.pkg_common_utilities.EXIT_AND_REPORT (
            $$PLSQL_UNIT,
            'NORMAL',
            V_flat_file_counts_txt);
           
    ELSE
        threshold_message :=
               'Unexpected High Update Volume: '
            || cntr
            || ' Update Threshold: '
            || cntr_threshold
            || '. ';

        INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                        ERR_MODULE,
                                        ERR_OID,
                                        ERR_MESSAGE)
             VALUES (SYSDATE,
                     $$PLSQL_UNIT,
                     'WH_ASSETS',
                     threshold_message);

        COMMIT;
        wh_common.pkg_common_utilities.exit_and_report ($$PLSQL_UNIT,
                                                        'FAILURE',
                                                        threshold_message);
        RAISE_APPLICATION_ERROR (-20010,
                                 $$PLSQL_UNIT || ' ' || threshold_message);
                                
    END IF;

    SELECT COUNT (*) INTO errlog_count FROM wh_assets.element_error_log;

    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in element error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'ELEMENT_WEEKLY_REFERSH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('element_error_log',
                         'Invalid data - check error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
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
        RAISE_APPLICATION_ERROR (-20010, $$PLSQL_UNIT || ' ' || G_SQLMSG);
END;
/
