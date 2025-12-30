CREATE OR REPLACE PROCEDURE nodes_yearly_snapshot
/**********************************************************************
This procedure creates the yearly snapshot of the nodes_history table

It is run yearly on 3/1/yyyy (or at freeze time) to implement the yearly snapshot.

Each row that is current (end date is null) in the nodes_history table is end-dated, and a new row is
inserted for the next year with a state = 'CURRENT'

03-06-2019 - SH - initial version
06-04-2019 - SH - End date old node outside of loop to avoid large rollback segment generation
                  Look up new section_id
06-06-2019 - SH - Move to Prod
04-04-2021 SH - Remove commit from fetch loop to avoid snapshot too old, rollback segment too small (ora-01555),
               commit after all rows inserted

12-13-21 SH Add columns signal_id, signal_type, offset to support TRAFFIC_SIGNALS
**********************************************************************/
IS
BEGIN
    DECLARE
        CURSOR all_nodes IS
            SELECT county_code1,
                   county_code2,
                   county_name1,
                   county_name2,
                   created_by,
                   date_created,
                   date_modified,
                   element_id,
                   end_date,
                   factored_aadt,
                   federal_functional_class,
                   federal_functional_class_descr,
                   federal_urban_group,
                   federal_urban_group_descr,
                   federal_urban_rural,
                   federal_urban_rural_descr,
                   hass_descr,
                   jurisdiction,
                   latitude,
                   longitude,
                   mev,
                   modified_by,
                   nhs_status,
                   node_description,
                   node_id,
                   node_type,
                   no_of_legs,
                   offset,
                   primary_route_mp,
                   primary_route_name,
                   primary_route_num,
                   priority,
                   region1,
                   region2,
                   region_name1,
                   region_name2,
                   route_type,
                   section_id,
                   signal_id,
                   signal_type,
                   snapshot_year,
                   start_date,
                   state,
                   state_urban_rural,
                   state_urban_rural_descr,
                   townline_node,
                   town_code1,
                   town_code2,
                   town_name1,
                   town_name2,
                   traffic_signal
              FROM nodes_history
             WHERE end_date IS NULL;

        rec                      all_nodes%ROWTYPE;

        common_run_date          DATE := SYSDATE;
        current_year             NUMBER;
        last_snapshot_year       NUMBER;
        cntr                     NUMBER := 0;
        cntr_updated             NUMBER := 0;
        cntr_added               NUMBER := 0;
        G_owner                  VARCHAR2 (20) := 'WH_ASSETS';
        G_jobname                VARCHAR2 (30) := $$PLSQL_UNIT;
        g_start_time             DATE := SYSDATE;
        g_object                 VARCHAR2 (21) := 'NODES_HISTORY';
        G_SQLMSG                 VARCHAR2 (1000) := NULL;
        V_flat_file_counts_txt   VARCHAR2 (1000) := NULL;
        errlog_count             NUMBER;
        err_log_message          VARCHAR2 (200) := NULL;
        tsection_id              NUMBER;

        FUNCTION Get_Current_Section_Id (ele_id IN NUMBER, sect_id IN NUMBER)
            RETURN NUMBER
        IS
            err                  VARCHAR2 (400);
            current_section_id   NUMBER := 0;
            boffset              NUMBER;
            eoffset              NUMBER;
        BEGIN
            SELECT begin_offset, end_offset        -- Get the begin/end offset
              INTO boffset, eoffset
              FROM sections_history s
             WHERE     sect_id = s.section_id
                   AND snapshot_year = last_snapshot_year
                   AND state = 'PAST';

            SELECT section_id                    -- Get the current section_id
              INTO current_section_id
              FROM sections s
             WHERE     s.element_id = ele_id
                   AND s.begin_offset = boffset
                   AND s.end_offset = eoffset;

            RETURN current_section_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN 0;
            WHEN OTHERS
            THEN
                err :=
                       'Error num :'
                    || TO_CHAR (SQLCODE)
                    || ' '
                    || SUBSTR (SQLERRM, 1, 70);

                INSERT INTO data_exceptions (TABLE_NAME,
                                             ERROR_CONDITION,
                                             TEST_PROCEDURE,
                                             TEST_DATE,
                                             ASSESSMENT,
                                             COLUMN_NAME1,
                                             COLUMN_VALUE1,
                                             COLUMN_NAME2,
                                             COLUMN_VALUE2)
                     VALUES ('NODES',
                             err,
                             $$PLSQL_UNIT,
                             g_start_time,
                             'EXCEPTION',
                             'FUNCTION',
                             'Get_Curr_Section_ID',
                             'SECTION_ID',
                             sect_id);

                RETURN 0;
        END;
    BEGIN
        SELECT MAX (snapshot_year) INTO last_snapshot_year FROM nodes_history;

        current_year := last_snapshot_year + 1;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE NODES_ERROR_LOG';

        OPEN all_nodes;

        LOOP
            FETCH all_nodes INTO rec;

            EXIT WHEN all_nodes%NOTFOUND;

            tsection_id :=
                Get_current_section_id (rec.element_id, rec.section_id);

            -- Insert new node record
            INSERT INTO nodes_history (county_code1,
                                       county_code2,
                                       county_name1,
                                       county_name2,
                                       created_by,
                                       date_created,
                                       date_modified,
                                       element_id,
                                       end_date,
                                       factored_aadt,
                                       federal_functional_class,
                                       federal_functional_class_descr,
                                       federal_urban_group,
                                       federal_urban_group_descr,
                                       federal_urban_rural,
                                       federal_urban_rural_descr,
                                       hass_descr,
                                       jurisdiction,
                                       latitude,
                                       longitude,
                                       mev,
                                       modified_by,
                                       nhs_status,
                                       node_description,
                                       node_id,
                                       node_type,
                                       no_of_legs,
                                       offset,
                                       primary_route_mp,
                                       primary_route_name,
                                       primary_route_num,
                                       priority,
                                       region1,
                                       region2,
                                       region_name1,
                                       region_name2,
                                       route_type,
                                       section_id,
                                       signal_id,
                                       signal_type,
                                       snapshot_year,
                                       start_date,
                                       state,
                                       state_urban_rural,
                                       state_urban_rural_descr,
                                       townline_node,
                                       town_code1,
                                       town_code2,
                                       town_name1,
                                       town_name2,
                                       traffic_signal)
                 VALUES (rec.county_code1,
                         rec.county_code2,
                         rec.county_name1,
                         rec.county_name2,
                         'NODES_YEARLY_SNAPSHOT',                -- created by
                         common_run_date,                      -- date created
                         NULL,                               -- DATE_MODIFIED,
                         rec.element_id,
                         NULL,                                    -- end_date,
                         rec.factored_aadt,
                         rec.federal_functional_class,
                         rec.federal_functional_class_descr,
                         rec.federal_urban_group,
                         rec.federal_urban_group_descr,
                         rec.federal_urban_rural,
                         rec.federal_urban_rural_descr,
                         rec.hass_descr,
                         rec.jurisdiction,
                         rec.latitude,
                         rec.longitude,
                         rec.mev,
                         NULL,                                 -- modified_by,
                         rec.nhs_status,
                         rec.node_description,
                         rec.node_id,
                         rec.node_type,
                         rec.no_of_legs,
                         rec.offset,
                         rec.primary_route_mp,
                         rec.primary_route_name,
                         rec.primary_route_num,
                         rec.priority,
                         rec.region1,
                         rec.region2,
                         rec.region_name1,
                         rec.region_name2,
                         rec.route_type,
                         tsection_id,
                         rec.signal_id,
                         rec.signal_type,
                         CURRENT_YEAR,                       -- SNAPSHOT_YEAR,
                         common_run_date,                       -- START_DATE,
                         'CURRENT',                                  -- STATE,
                         rec.state_urban_rural,
                         rec.state_urban_rural_descr,
                         rec.townline_node,
                         rec.town_code1,
                         rec.town_code2,
                         rec.town_name1,
                         rec.town_name2,
                         rec.traffic_signal)
                    LOG ERRORS INTO nodes_error_log
                            ('NODE_YEARLY_SNAPSHOT ' || SYSDATE)
                            REJECT LIMIT 100;

            cntr_added := cntr_added + 1;
        END LOOP;

        CLOSE all_nodes;

        COMMIT;

        -- End date old nodes


        -- Set counter updated for reporting

        SELECT COUNT (*)
          INTO cntr_updated
          FROM nodes_history
         WHERE snapshot_year = last_snapshot_year AND end_date IS NULL;


        -- End date old node recs

        UPDATE nodes_history
           SET end_date = common_run_date,
               date_modified = common_run_date,
               modified_by = 'YEARLY_SNAPSHOT',
               state = 'PAST'
         WHERE snapshot_year = last_snapshot_year AND end_date IS NULL;


        COMMIT;

        SELECT COUNT (*) INTO errlog_count FROM nodes_error_log;

        IF errlog_count > 0
        THEN
            BEGIN
                err_log_message :=
                    'Unexpected Data Quality Issues in nodes_error_log ';

                INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                                ERR_MODULE,
                                                ERR_OID,
                                                ERR_MESSAGE)
                     VALUES (SYSDATE,
                             'nodes_yearly_snapshot',
                             'WH_ASSETS',
                             err_log_message);

                COMMIT;
                wh_common.pkg_common_utilities.exit_and_report (
                    $$PLSQL_UNIT,
                    'FAILURE',
                    err_log_message);
                RAISE_APPLICATION_ERROR (
                    -20010,
                    $$PLSQL_UNIT || ' ' || err_log_message);
            END;
        ELSE                                                 -- Successful Run
            BEGIN
                SELECT COUNT (*) INTO cntr FROM nodes_history;

                WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
                    OWNER         => G_OWNER,
                    OBJECT_NAME   => g_object,
                    object_cnt    => cntr,
                    add_cnt       => cntr_added,
                    update_cnt    => cntr_updated,
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
            RAISE_APPLICATION_ERROR (-20010, $$PLSQL_UNIT || ' ' || G_SQLMSG);
    END;
END;
/
