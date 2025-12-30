CREATE OR REPLACE PROCEDURE ibridge_roads_yearly_snapshot
IS
    /**********************************************************************

    This procedure creates the yearly snapshot of the ibrdg_roads_assoc_history table

 It is run yearly on 3/1/yyyy (or at freeze time) to implement the yearly snapshot.

 Each row that is current (end date is null) in the ibrdg_roads_assoc_history table is end-dated, and a new row is
 inserted for the next year with a state = 'CURRENT'.

 It looks up the new bridge_id, highway_id, section_id, and begin/end section offsets so must be run after the yearly
 snapshot of the highways_history, roadway_sections_history, and ibridges_history tables.

   Modification History:

   05-31-2017 SH Initial Version
   11-28-2018 SH - Modify  references to roadway_sections view to roadway_sections_history table where end_date is null
                   and highways view to use highways_history table where end_date is null in preparation for going to full network
   02-06-2019 SH - Change highways_history to element_history, roadway_section_history to NEW_SECTIONS_HISTORY to use full network
   02-14-2019 SH - Change new_sections_history to sections_history
   03-25-2019 SH - Move version in wh_assets_dev to test
   06-04-2019 SH - End date old section outside of loop to avoid large rollback segment generation
   11-26-2019 SH - Add column MTRNS_ASSETNO  (bridge pointer) to provide the relationship for the underclearance height restrictions from InspectTech)
   04-03-2020 SH - Moved to production in preparation of yearly snapshot
   04-04-2021 SH - Remove commit from fetch loop to avoid snapshot too old, rollback segment too small (ora-01555), 
                   commit after all rows inserted
    **********************************************************************/

    cnt                     NUMBER;
    cntr_updated            NUMBER;
    cntr_added              NUMBER;
    common_run_date         DATE := SYSDATE;
    err_log_message         VARCHAR2 (200) := NULL;
    errlog_count            NUMBER := 0;
    current_year            NUMBER;
    last_snapshot_year      NUMBER;
    g_owner                 VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname               VARCHAR2 (30) := 'ibridge_rds_yrly_snap';
    g_object                VARCHAR2 (30) := 'ibrdg_roads_assoc_history';

    tbridge_id              NUMBER;
    thighway_id             NUMBER;
    tsection_id             NUMBER;
    tbegin_section_offset   NUMBER;
    tend_section_offset     NUMBER;
BEGIN
    DECLARE
        CURSOR roads
        IS
            SELECT bridge_number,
                   element_id,
                   invrte_adt,
                   invrte_adt_truck_percent,
                   invrte_adt_yr,
                   invrte_detour_length,
                   invrte_dirsuffix,
                   invrte_dirsuffix_descr,
                   invrte_functionclass,
                   invrte_functionclass_descr,
                   invrte_horiz_clear,
                   invrte_level_of_serv,
                   invrte_level_of_serv_descr,
                   invrte_lrs_rtenum,
                   invrte_lrs_subrtenum,
                   invrte_milepoint,
                   invrte_min_vert_clear,
                   invrte_on_base_hwynet,
                   invrte_on_base_hwynet_descr,
                   invrte_on_nhs,
                   invrte_on_nhs_descr,
                   invrte_on_strahnet,
                   invrte_on_strahnet_descr,
                   invrte_on_trucknet,
                   invrte_on_trucknet_descr,
                   invrte_rectype,
                   invrte_rtenum,
                   invrte_signprefix,
                   invrte_signprefix_descr,
                   invrte_toll,
                   invrte_toll_descr,
                   invrte_traffic_dir,
                   invrte_traffic_dir_descr,
                   location_level,
                   location_type,
                   mtrns_assetno,
                   offset,
                   primary_route_name,
                   primary_route_number
              FROM ibrdg_roads_assoc_history
             WHERE end_date IS NULL;

        rec   roads%ROWTYPE;

        FUNCTION Get_Element_wid (ele_id IN NUMBER)
            RETURN NUMBER
        IS
            hiway_id   NUMBER;
            err        VARCHAR2 (100);
        BEGIN
            SELECT h.element_wid
              INTO hiway_id
              FROM element_history h
             WHERE h.end_date IS NULL AND ele_id = h.element_id;

            RETURN hiway_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                err :=
                    'element_id associated with a bridge road not in highways view';

                INSERT INTO data_exceptions (TABLE_NAME,
                                             ERROR_CONDITION,
                                             TEST_PROCEDURE,
                                             TEST_DATE,
                                             ASSESSMENT,
                                             COLUMN_NAME1,
                                             COLUMN_VALUE1,
                                             COLUMN_NAME2,
                                             COLUMN_VALUE2)
                     VALUES (g_object,
                             err,
                             g_jobname,
                             common_run_date,
                             'EXCEPTION',
                             'FUNCTION',
                             'GET_HIGHWY_ID',
                             'ELEMENT_ID',
                             ele_id);

                RETURN NULL;
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
                     VALUES (g_object,
                             err,
                             g_jobname,
                             common_run_date,
                             'EXCEPTION',
                             'FUNCTION',
                             'GET_HIGHWY_ID',
                             'ELEMENT_ID',
                             ele_id);

                RETURN NULL;
        END;


        FUNCTION get_bridge_id (brdg_num IN NUMBER)
            RETURN NUMBER
        IS
            brdg_id   NUMBER;
            err       VARCHAR2 (100);
        BEGIN
            SELECT DISTINCT b.bridge_id
              INTO brdg_id
              FROM ibridges_history b
             WHERE b.bridge_number = brdg_num AND b.end_date IS NULL;

            RETURN brdg_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                err := 'Bridge without a bridge_id in ibridges_history)';

                INSERT INTO data_exceptions (TABLE_NAME,
                                             ERROR_CONDITION,
                                             TEST_PROCEDURE,
                                             TEST_DATE,
                                             ASSESSMENT,
                                             COLUMN_NAME1,
                                             COLUMN_VALUE1,
                                             COLUMN_NAME2,
                                             COLUMN_VALUE2)
                     VALUES (g_object,
                             err,
                             g_jobname,
                             common_run_date,
                             'EXCEPTION',
                             'FUNCTION',
                             'GET_BRIDGE_ID',
                             'BRIDGE_NUMBER',
                             brdg_num);

                RETURN NULL;
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
                     VALUES (g_object,
                             err,
                             g_jobname,
                             common_run_date,
                             'EXCEPTION',
                             'FUNCTION',
                             'GET_BRIDGE_ID',
                             'BRIDGE_NUMBER',
                             brdg_num);

                RETURN NULL;
        END;

        PROCEDURE Get_section_id (ele_id           IN     NUMBER,
                                  brdg_offset      IN     NUMBER,
                                  sec_id              OUT NUMBER,
                                  beg_sec_offset      OUT NUMBER,
                                  end_sec_offset      OUT NUMBER)
        IS
            cntr   NUMBER;
            err    VARCHAR2 (100);
        BEGIN
            cntr := 0;
            sec_id := 0;
            beg_sec_offset := 0;
            end_sec_offset := 0;

            --  Check to see if the bridge is located on a section boundary
            SELECT COUNT (*)
              INTO cntr
              FROM SECTIONS_HISTORY s
             WHERE (    ele_id = s.element_id
                    AND s.end_date IS NULL
                    AND brdg_offset >= S.BEGIN_OFFSET
                    AND brdg_offset <= S.end_OFFSET);

            IF cntr = 1                           -- not on a section boundary
            THEN
                SELECT S.SECTION_ID, s.begin_offset, s.end_offset
                  INTO sec_id, beg_sec_offset, end_sec_offset
                  FROM SECTIONS_HISTORY s
                 WHERE (    ele_id = s.element_id
                        AND s.end_date IS NULL
                        AND brdg_offset >= S.BEGIN_OFFSET
                        AND brdg_offset <= S.end_OFFSET);
            END IF;

            IF cntr > 1
            THEN -- bridge is on a section boundary, the low order section is chosen
                SELECT S.SECTION_ID, s.begin_offset, s.end_offset
                  INTO sec_id, beg_sec_offset, end_sec_offset
                  FROM SECTIONS_HISTORY s
                 WHERE (    ele_id = s.element_id
                        AND s.end_date IS NULL
                        AND brdg_offset > S.BEGIN_OFFSET
                        AND brdg_offset <= S.END_OFFSET);
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND -- section associated with a bridge/offset not in roadway_sections
            THEN
                err := 'No section found for element id/offset';

                INSERT INTO data_exceptions (TABLE_NAME,
                                             ERROR_CONDITION,
                                             TEST_PROCEDURE,
                                             TEST_DATE,
                                             ASSESSMENT,
                                             COLUMN_NAME1,
                                             COLUMN_VALUE1,
                                             COLUMN_NAME2,
                                             COLUMN_VALUE2,
                                             COLUMN_NAME3,
                                             COLUMN_VALUE3)
                     VALUES (g_object,
                             err,
                             g_jobname,
                             common_run_date,
                             'EXCEPTION',
                             'FUNCTION',
                             'GET_SECTION_ID',
                             'ELEMENT_ID',
                             ele_id,
                             'OFFSET',
                             brdg_offset);
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
                                             COLUMN_VALUE2,
                                             COLUMN_NAME3,
                                             COLUMN_VALUE3)
                     VALUES (g_object,
                             err,
                             g_jobname,
                             common_run_date,
                             'EXCEPTION',
                             'FUNCTION',
                             'GET_SECTION_ID',
                             'ELEMENT_ID',
                             ele_id,
                             'OFFSET',
                             brdg_offset);
        END;



        PROCEDURE Insert_duplicate_row
        IS
        BEGIN
            INSERT INTO ibrdg_roads_assoc_history (
                            begin_section_offset,
                            bridge_id,
                            bridge_number,
                            created_by,
                            date_created,
                            date_modified,
                            element_id,
                            end_date,
                            end_section_offset,
                            highway_id,
                            invrte_adt,
                            invrte_adt_truck_percent,
                            invrte_adt_yr,
                            invrte_detour_length,
                            invrte_dirsuffix,
                            invrte_dirsuffix_descr,
                            invrte_functionclass,
                            invrte_functionclass_descr,
                            invrte_horiz_clear,
                            invrte_level_of_serv,
                            invrte_level_of_serv_descr,
                            invrte_lrs_rtenum,
                            invrte_lrs_subrtenum,
                            invrte_milepoint,
                            invrte_min_vert_clear,
                            invrte_on_base_hwynet,
                            invrte_on_base_hwynet_descr,
                            invrte_on_nhs,
                            invrte_on_nhs_descr,
                            invrte_on_strahnet,
                            invrte_on_strahnet_descr,
                            invrte_on_trucknet,
                            invrte_on_trucknet_descr,
                            invrte_rectype,
                            invrte_rtenum,
                            invrte_signprefix,
                            invrte_signprefix_descr,
                            invrte_toll,
                            invrte_toll_descr,
                            invrte_traffic_dir,
                            invrte_traffic_dir_descr,
                            location_level,
                            location_type,
                            mtrns_assetno,
                            modified_by,
                            offset,
                            primary_route_name,
                            primary_route_number,
                            section_id,
                            snapshot_year,
                            start_date,
                            state)
                 VALUES (tbegin_section_offset,
                         tbridge_id,
                         rec.bridge_number,
                         'ibridge_roads_yrly_snap',             -- CREATED_BY,
                         common_run_date,                     -- DATE_CREATED,
                         NULL,                               -- DATE_MODIFIED,
                         rec.element_id,
                         NULL,                                    -- END_DATE,
                         tend_section_offset,
                         thighway_id,
                         rec.invrte_adt,
                         rec.invrte_adt_truck_percent,
                         rec.invrte_adt_yr,
                         rec.invrte_detour_length,
                         rec.invrte_dirsuffix,
                         rec.invrte_dirsuffix_descr,
                         rec.invrte_functionclass,
                         rec.invrte_functionclass_descr,
                         rec.invrte_horiz_clear,
                         rec.invrte_level_of_serv,
                         rec.invrte_level_of_serv_descr,
                         rec.invrte_lrs_rtenum,
                         rec.invrte_lrs_subrtenum,
                         rec.invrte_milepoint,
                         rec.invrte_min_vert_clear,
                         rec.invrte_on_base_hwynet,
                         rec.invrte_on_base_hwynet_descr,
                         rec.invrte_on_nhs,
                         rec.invrte_on_nhs_descr,
                         rec.invrte_on_strahnet,
                         rec.invrte_on_strahnet_descr,
                         rec.invrte_on_trucknet,
                         rec.invrte_on_trucknet_descr,
                         rec.invrte_rectype,
                         rec.invrte_rtenum,
                         rec.invrte_signprefix,
                         rec.invrte_signprefix_descr,
                         rec.invrte_toll,
                         rec.invrte_toll_descr,
                         rec.invrte_traffic_dir,
                         rec.invrte_traffic_dir_descr,
                         rec.location_level,
                         rec.location_type,
                         rec.mtrns_assetno,
                         NULL,                                 -- MODIFIED_BY,
                         rec.offset,
                         rec.primary_route_name,
                         rec.primary_route_number,
                         tsection_id,
                         current_year,                       -- SNAPSHOT_YEAR,
                         common_run_date,                       -- START_DATE,
                         'CURRENT')                                   -- STATE
                    LOG ERRORS INTO IBRIDGE_ROADS_ASSOC_ERROR_LOG
                            ('IBRIDGE_ROADS_YEARLY_SNAPSHOT ' || SYSDATE)
                            REJECT LIMIT 100;
        END;
   
 BEGIN
        SELECT MAX (snapshot_year)
          INTO last_snapshot_year
          FROM ibrdg_roads_assoc_history;

        current_year := last_snapshot_year + 1;


        EXECUTE IMMEDIATE 'TRUNCATE TABLE IBRIDGE_ROADS_ASSOC_ERROR_LOG';

        OPEN roads;

        LOOP
            FETCH roads INTO rec;

            EXIT WHEN roads%NOTFOUND;

            -- Insert new ROAD ASSOCIATED record
            tbridge_id := get_bridge_id (rec.bridge_number);
            thighway_id := get_element_wid (rec.element_id);
            get_section_id (rec.element_id,
                            rec.offset,
                            tsection_id,
                            tbegin_section_offset,
                            tend_section_offset);

            insert_duplicate_row;
            cntr_added := cntr_added + 1;
        END LOOP;

        CLOSE ROADS;


        COMMIT;

        -- Set counter updated for reporting

        SELECT COUNT (*)
          INTO cntr_updated
          FROM ibrdg_roads_assoc_history
         WHERE snapshot_year = last_snapshot_year AND end_date IS NULL;


        -- End date old bridge roads associated rows

        UPDATE ibrdg_roads_assoc_history
           SET end_date = common_run_date,
               date_modified = common_run_date,
               modified_by = 'YEARLY_SNAPSHOT',
               state = 'PAST'
         WHERE snapshot_year = last_snapshot_year AND end_date IS NULL;


        COMMIT;

        SELECT COUNT (*) INTO errlog_count FROM ibridge_roads_assoc_error_log;

        IF errlog_count > 0
        THEN
            BEGIN
                err_log_message :=
                    'Unexpected Data Quality Issues in roads_under_bridge error log: ';

                INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                                ERR_MODULE,
                                                ERR_OID,
                                                ERR_MESSAGE)
                     VALUES (SYSDATE,
                             g_jobname,
                             'WH_ASSETS',
                             err_log_message);

                COMMIT;
                wh_common.pkg_common_utilities.exit_and_report (
                    $$PLSQL_UNIT,
                    'FAILURE',
                    err_log_message);
            END;
        END IF;


        SELECT COUNT (*) INTO cnt FROM ibrdg_roads_assoc_history;

        WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
            OWNER         => 'WH_ASSETS',
            OBJECT_NAME   => g_object,
            object_cnt    => cnt,
            proc          => $$PLSQL_UNIT,
            start_time    => common_run_date);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            wh_common.pkg_common_utilities.update_whse_log (
                'WH_ASSETS',
                $$PLSQL_UNIT,
                NULL,
                NULL,
                NULL,
                NULL,
                   'Error during '
                || $$PLSQL_UNIT
                || ' Line:'
                || $$PLSQL_LINE
                || ': '
                || SUBSTR (SQLERRM, 1, 400),
                'Failed');
            wh_common.pkg_common_utilities.exit_and_report (
                $$PLSQL_UNIT,
                'FAILURE',
                   'Error during '
                || $$PLSQL_UNIT
                || ': '
                || SUBSTR (SQLERRM, 1, 400));
            RAISE_APPLICATION_ERROR (
                -20050,
                $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
    END;
END;
/
