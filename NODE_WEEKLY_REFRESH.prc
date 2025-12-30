CREATE OR REPLACE PROCEDURE node_weekly_refresh (
    staging_already_loaded   IN VARCHAR2 := 'N',
    cntr_threshold           IN NUMBER := 300000)
IS
    /**********************************************************************
    This procedure loads the nodes_staging table & compares it to the nodes_history table
    for the weekly refresh.  New nodes are added.  Old nodes are 'RETIRED'.

    Changed nodes cause the current nodes row to be updated with the new values.

    03-06-2019 SH - Initial version
   
    12-13-21 SH Add columns signal_id, signal_type, offset to support TRAFFIC_SIGNALS
    **********************************************************************/


    CURSOR changes
    IS
        SELECT COUNTY_CODE1,
               COUNTY_CODE2,
               COUNTY_NAME1,
               COUNTY_NAME2,
               ELEMENT_ID,
               FACTORED_AADT,
               FEDERAL_FUNCTIONAL_CLASS,
               FEDERAL_FUNCTIONAL_CLASS_DESCR,
               FEDERAL_URBAN_GROUP,
               FEDERAL_URBAN_GROUP_DESCR,
               FEDERAL_URBAN_RURAL,
               FEDERAL_URBAN_RURAL_DESCR,
               HASS_DESCR,
               JURISDICTION,
               LATITUDE,
               LONGITUDE,
               MEV,
               NHS_STATUS,
               NODE_DESCRIPTION,
               NODE_ID,
               NODE_TYPE,
               NO_OF_LEGS,
               OFFSET,
               PRIMARY_ROUTE_MP,
               PRIMARY_ROUTE_NAME,
               PRIMARY_ROUTE_NUM,
               PRIORITY,
               REGION1,
               REGION2,
               REGION_NAME1,
               REGION_NAME2,
               ROUTE_TYPE,
               SECTION_ID,
               SIGNAL_ID, SIGNAL_TYPE,
               STATE_URBAN_RURAL,
               STATE_URBAN_RURAL_DESCR,
               TOWNLINE_NODE,
               TOWN_CODE1,
               TOWN_CODE2,
               TOWN_NAME1,
               TOWN_NAME2,
               TRAFFIC_SIGNAL
          FROM nodes_staging
        MINUS
        SELECT COUNTY_CODE1,
               COUNTY_CODE2,
               COUNTY_NAME1,
               COUNTY_NAME2,
               ELEMENT_ID,
               FACTORED_AADT,
               FEDERAL_FUNCTIONAL_CLASS,
               FEDERAL_FUNCTIONAL_CLASS_DESCR,
               FEDERAL_URBAN_GROUP,
               FEDERAL_URBAN_GROUP_DESCR,
               FEDERAL_URBAN_RURAL,
               FEDERAL_URBAN_RURAL_DESCR,
               HASS_DESCR,
               JURISDICTION,
               LATITUDE,
               LONGITUDE,
               MEV,
               NHS_STATUS,
               NODE_DESCRIPTION,
               NODE_ID,
               NODE_TYPE,
               NO_OF_LEGS,
               OFFSET,
               PRIMARY_ROUTE_MP,
               PRIMARY_ROUTE_NAME,
               PRIMARY_ROUTE_NUM,
               PRIORITY,
               REGION1,
               REGION2,
               REGION_NAME1,
               REGION_NAME2,
               ROUTE_TYPE,
               SECTION_ID,
               SIGNAL_ID, SIGNAL_TYPE,
               STATE_URBAN_RURAL,
               STATE_URBAN_RURAL_DESCR,
               TOWNLINE_NODE,
               TOWN_CODE1,
               TOWN_CODE2,
               TOWN_NAME1,
               TOWN_NAME2,
               TRAFFIC_SIGNAL
          FROM nodes_history
         WHERE end_date IS NULL;

    CURSOR retired_node_list
    IS
        SELECT node_id
          FROM nodes_history
         WHERE end_date IS NULL
        MINUS
        SELECT node_id FROM nodes_staging;

    cntr_retired               NUMBER (9) := 0;
    cntr                       NUMBER (9) := 0;
    threshold_message          VARCHAR2 (200) := NULL;
    cntr_updated               NUMBER (9) := 0;
    cntr_added                 NUMBER (9) := 0;
    g_owner                    VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                  VARCHAR2 (30) := 'NODE_WEEKLY_REFRESH';
    g_object                   VARCHAR2 (20) := 'NODES_HISTORY';
    g_sqlmsg                   VARCHAR2 (500) := NULL;
    V_flat_file_counts_txt     VARCHAR2 (1000) := NULL;
    initial_number_lanes       NUMBER (5) := 0;
    current_element_wid        NUMBER;
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
      FROM nodes_history
     WHERE STATE = 'CURRENT';

    IF staging_already_loaded = 'N'
    THEN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE nodes_error_log';

        load_nodes_staging;
        node_diffs;
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
              FROM nodes_history
             WHERE node_id = rec.node_id AND end_date IS NULL;

            IF cntr > 0
            THEN -- update the existing element that has some attributes that have changed
                BEGIN
                    UPDATE nodes_history
                       SET date_modified = g_start_time,
                           modified_by = 'NODES WEEKLY REFRESH',
                           COUNTY_CODE1 = REC.COUNTY_CODE1,
                           COUNTY_CODE2 = REC.COUNTY_CODE2,
                           COUNTY_NAME1 = REC.COUNTY_NAME1,
                           COUNTY_NAME2 = REC.COUNTY_NAME2,
                           ELEMENT_ID = REC.ELEMENT_ID,
                           FACTORED_AADT = REC.FACTORED_AADT,
                           FEDERAL_FUNCTIONAL_CLASS =
                               REC.FEDERAL_FUNCTIONAL_CLASS,
                           FEDERAL_FUNCTIONAL_CLASS_DESCR =
                               REC.FEDERAL_FUNCTIONAL_CLASS_DESCR,
                           FEDERAL_URBAN_GROUP = REC.FEDERAL_URBAN_GROUP,
                           FEDERAL_URBAN_GROUP_DESCR =
                               REC.FEDERAL_URBAN_GROUP_DESCR,
                           FEDERAL_URBAN_RURAL = REC.FEDERAL_URBAN_RURAL,
                           FEDERAL_URBAN_RURAL_DESCR =
                               REC.FEDERAL_URBAN_RURAL_DESCR,
                           HASS_DESCR = REC.HASS_DESCR,
                           JURISDICTION = REC.JURISDICTION,
                           LATITUDE = REC.LATITUDE,
                           LONGITUDE = REC.LONGITUDE,
                           MEV = REC.MEV,
                           NHS_STATUS = REC.NHS_STATUS,
                           NODE_DESCRIPTION = REC.NODE_DESCRIPTION,
                           NODE_TYPE = REC.NODE_TYPE,
                           NO_OF_LEGS = REC.NO_OF_LEGS,
                           OFFSET = REC.OFFSET,
                           PRIMARY_ROUTE_MP = REC.PRIMARY_ROUTE_MP,
                           PRIMARY_ROUTE_NAME = REC.PRIMARY_ROUTE_NAME,
                           PRIMARY_ROUTE_NUM = REC.PRIMARY_ROUTE_NUM,
                           PRIORITY = REC.PRIORITY,
                           REGION1 = REC.REGION1,
                           REGION2 = REC.REGION2,
                           REGION_NAME1 = REC.REGION_NAME1,
                           REGION_NAME2 = REC.REGION_NAME2,
                           ROUTE_TYPE = REC.ROUTE_TYPE,
                           SECTION_ID = REC.SECTION_ID,
                           SIGNAL_ID = REC.SIGNAL_ID,
                           SIGNAL_TYPE = REC.SIGNAL_TYPE,
                           STATE_URBAN_RURAL = REC.STATE_URBAN_RURAL,
                           STATE_URBAN_RURAL_DESCR =
                               REC.STATE_URBAN_RURAL_DESCR,
                           TOWNLINE_NODE = REC.TOWNLINE_NODE,
                           TOWN_CODE1 = REC.TOWN_CODE1,
                           TOWN_CODE2 = REC.TOWN_CODE2,
                           TOWN_NAME1 = REC.TOWN_NAME1,
                           TOWN_NAME2 = REC.TOWN_NAME2,
                           TRAFFIC_SIGNAL = REC.TRAFFIC_SIGNAL
                     WHERE node_id = rec.node_id AND end_date IS NULL
                       LOG ERRORS INTO nodes_error_log
                               (   'Nodes Weekly Refresh - Update Node: '
                                || SYSDATE)
                               REJECT LIMIT 100;

                    cntr_updated := cntr_updated + 1;
                END;
            ELSE                    -- add a new node not yet in the data mart
                BEGIN
                    cntr_added := cntr_added + 1;

                    INSERT INTO nodes_history (
                                    date_created,
                                    start_date,
                                    created_by,
                                    COUNTY_CODE1,
                                    COUNTY_CODE2,
                                    COUNTY_NAME1,
                                    COUNTY_NAME2,
                                    ELEMENT_ID,
                                    FACTORED_AADT,
                                    FEDERAL_FUNCTIONAL_CLASS,
                                    FEDERAL_FUNCTIONAL_CLASS_DESCR,
                                    FEDERAL_URBAN_GROUP,
                                    FEDERAL_URBAN_GROUP_DESCR,
                                    FEDERAL_URBAN_RURAL,
                                    FEDERAL_URBAN_RURAL_DESCR,
                                    HASS_DESCR,
                                    JURISDICTION,
                                    LATITUDE,
                                    LONGITUDE,
                                    MEV,
                                    NHS_STATUS,
                                    NODE_DESCRIPTION,
                                    NODE_ID,
                                    NODE_TYPE,
                                    NO_OF_LEGS,
                                    OFFSET,
                                    PRIMARY_ROUTE_MP,
                                    PRIMARY_ROUTE_NAME,
                                    PRIMARY_ROUTE_NUM,
                                    PRIORITY,
                                    REGION1,
                                    REGION2,
                                    REGION_NAME1,
                                    REGION_NAME2,
                                    ROUTE_TYPE,
                                    SECTION_ID,
                                    SIGNAL_ID, SIGNAL_TYPE,
                                    STATE_URBAN_RURAL,
                                    STATE_URBAN_RURAL_DESCR,
                                    TOWNLINE_NODE,
                                    TOWN_CODE1,
                                    TOWN_CODE2,
                                    TOWN_NAME1,
                                    TOWN_NAME2,
                                    TRAFFIC_SIGNAL,
                                    snapshot_year,
                                    state)
                             VALUES (g_start_time,
                                     g_start_time,
                                     'NODES WEEKLY REFRESH',
                                     REC.COUNTY_CODE1,
                                     REC.COUNTY_CODE2,
                                     REC.COUNTY_NAME1,
                                     REC.COUNTY_NAME2,
                                     REC.ELEMENT_ID,
                                     REC.FACTORED_AADT,
                                     REC.FEDERAL_FUNCTIONAL_CLASS,
                                     REC.FEDERAL_FUNCTIONAL_CLASS_DESCR,
                                     REC.FEDERAL_URBAN_GROUP,
                                     REC.FEDERAL_URBAN_GROUP_DESCR,
                                     REC.FEDERAL_URBAN_RURAL,
                                     REC.FEDERAL_URBAN_RURAL_DESCR,
                                     REC.HASS_DESCR,
                                     REC.JURISDICTION,
                                     REC.LATITUDE,
                                     REC.LONGITUDE,
                                     REC.MEV,
                                     REC.NHS_STATUS,
                                     REC.NODE_DESCRIPTION,
                                     REC.NODE_ID,
                                     REC.NODE_TYPE,
                                     REC.NO_OF_LEGS,
                                     REC.OFFSET,
                                     REC.PRIMARY_ROUTE_MP,
                                     REC.PRIMARY_ROUTE_NAME,
                                     REC.PRIMARY_ROUTE_NUM,
                                     REC.PRIORITY,
                                     REC.REGION1,
                                     REC.REGION2,
                                     REC.REGION_NAME1,
                                     REC.REGION_NAME2,
                                     REC.ROUTE_TYPE,
                                     REC.SECTION_ID,
                                     REC.SIGNAL_ID, REC.SIGNAL_TYPE,
                                     REC.STATE_URBAN_RURAL,
                                     REC.STATE_URBAN_RURAL_DESCR,
                                     REC.TOWNLINE_NODE,
                                     REC.TOWN_CODE1,
                                     REC.TOWN_CODE2,
                                     REC.TOWN_NAME1,
                                     REC.TOWN_NAME2,
                                     REC.TRAFFIC_SIGNAL,
                                     current_year,
                                     'CURRENT')
                            LOG ERRORS INTO nodes_error_log
                                    (   'Nodes Weekly Refresh - Insert Node: '
                                     || SYSDATE)
                                    REJECT LIMIT 100;

                    INSERT INTO node_changes                     -- log insert
                                             (node_id,
                                              change_type,
                                              change_date,
                                              column_name,
                                              table_name,
                                              modified_by,
                                              old_value,
                                              new_value)
                         VALUES (rec.node_id,
                                 'I',
                                 g_start_time ,
                                NULL,
                                 g_object,
                                 $$PLSQL_UNIT,
                                 NULL,
                                 NULL);
                END;
            END IF;
        END LOOP;


        FOR rec IN retired_node_list 
        LOOP
            BEGIN
                

                UPDATE NODES_history
                   SET end_date = g_start_time,
                       date_modified = g_start_time,
                       state = 'RETIRED'
                 WHERE NODE_id = rec.NODE_id AND end_date IS NULL;

                cntr_retired := cntr_retired + 1;
                cntr_updated := cntr_updated + 1;

                INSERT INTO NODE_CHANGES                 -- log delete
                                                 (node_id,
                                              change_type,
                                              change_date,
                                              column_name,
                                              table_name,
                                              modified_by,
                                              old_value,
                                              new_value)
                     VALUES (
                             rec.NODE_id,
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

        SELECT COUNT (*) INTO cntr FROM NODES_history;

        V_flat_file_counts_txt :=
               'NODES_HISTORY: '
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

    SELECT COUNT (*) INTO errlog_count FROM nodes_error_log;

    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in nodes error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (g_start_time,
                         'NODES_WEEKLY_REFERSH',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('nodes_error_log',
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
