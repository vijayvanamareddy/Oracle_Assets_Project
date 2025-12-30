CREATE OR REPLACE PROCEDURE fix_snapshot_2021
IS
    /**********************************************************************

    This procedure fixes federal_functional_class and federal_functional_class_descr on Route 0016X from
    milepoints 167.23 -187.86 in snapshot year 2021 (setting them to the 2022 values) due to an editing error made in Metrans

    It also fixes wcsh_code on route_number  '0003X' between milepoints 102.26  and 103.46 and route_number '0003W' and milepoints 0.08 and 0.18

    The elements are obtained from the routes view, the correct federal_functional_class and federal_functional_class_descr are
    obtained from the sections view AND nodes view

    The following tables are updated for snapshot year 2021
    sections_history, nodes_history, complete_transportation_network, and crashes_on_route_2021

    This procedure will only be run once but can be used as a model to fix other errors

    06-06-2022 SH Intial Version
    06-07-2022 SH Add fix for ffc in node crashes for crashes_on_route_2021
    06-13-2022 SH Add fix for ffc for nodes in complete_transportation_network
    06-24-2022 SH Add fix for ffc for nodes_history
                  ADD fix for WCSH_code editing error (not on element boundary)
    06-28-2022 SH Change range of fix on 0003X to 102.26 - 103.46 due to segmentation diffs between 2021 and 2022 (Re: TM)
    **********************************************************************/

    CURSOR ffc_section_changes IS
        SELECT DISTINCT element_id,
                        snapshot_year,
                        federal_functional_class,
                        federal_functional_class_descr
          FROM sections_history
         WHERE     snapshot_year = 2022
               AND element_id IN
                       (SELECT element_id
                          FROM routes
                         WHERE     route_number = '0016X'
                               AND begin_element_milepoint >= 167.23
                               AND end_element_milepoint <= 187.86);

    CURSOR node_ffc_changes IS
          SELECT node_id,
                 FEDERAL_FUNCTIONAL_CLASS,
                 FEDERAL_FUNCTIONAL_CLASS_DESCR
            FROM nodes
           WHERE     PRIMARY_ROUTE_NUM = '0016X'
                 AND PRIMARY_ROUTE_MP >= 167.23
                 AND PRIMARY_ROUTE_MP <= 187.86
        ORDER BY PRIMARY_ROUTE_MP;


    CURSOR secids IS -- used to update section_history and alternate routes on complete_transportation_network
          SELECT element_id,
                 section_id,
                 begin_section_mp,
                 end_section_mp,
                 wcsh_code
            FROM complete_transportation_network
           WHERE     SNAPSHOT_YEAR = 2021
                 AND ROUTE_NUMBER = '0003X'
                 AND row_type = 'Element'
                 AND BEGIN_SECTION_MP >= 102.26
                 AND end_section_mp <= 103.46
        ORDER BY begin_section_mp;


    cntr                     NUMBER := 0;

    err_log_message          VARCHAR2 (200);
    cntr_updated             NUMBER := 0;
    cntr_added               NUMBER := 0;
    cntr_replaced            NUMBER := 0;
    serrlog_count            NUMBER := 0;

    g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                VARCHAR2 (30) := 'FIX_FFC';
    g_start_time             DATE := SYSDATE;
    g_object                 VARCHAR2 (20) := 'SECTIONS_HISTORY';
    g_SQLMSG                 VARCHAR2 (1000);
    V_flat_file_counts_txt   VARCHAR2 (1000);
BEGIN
    EXECUTE IMMEDIATE 'truncate table sections_history_error_log';

    EXECUTE IMMEDIATE 'truncate table COMPLETE_NETWORK_ERROR_LOG';

    EXECUTE IMMEDIATE 'truncate table CRASHES_ON_ROUTE_ERROR_LOG';

    EXECUTE IMMEDIATE 'truncate table NODES_ERROR_LOG';


   

            FOR rec IN ffc_section_changes
            LOOP

                        UPDATE sections_history
                           SET
                               federal_functional_class =
                                   rec.federal_functional_class,
                               federal_functional_class_descr =
                                   rec.federal_functional_class_descr
                         WHERE     element_id = rec.element_id
                                   AND snapshot_year = 2021
                           LOG ERRORS INTO sections_history_error_log
                                   ('Fix FFC ' || SYSDATE)
                                   REJECT LIMIT 100;

                         UPDATE complete_transportation_network
                           SET
                               federal_functional_class =
                                   rec.federal_functional_class,
                               federal_functional_class_descr =
                                   rec.federal_functional_class_descr
                         WHERE     element_id = rec.element_id
                                   AND snapshot_year = 2021
                           LOG ERRORS INTO COMPLETE_NETWORK_ERROR_LOG
                                   ('Fix FFC ' || SYSDATE)
                                   REJECT LIMIT 100;


                       UPDATE crashes_on_route_2021
                       SET
                               federal_functional_class =
                                   rec.federal_functional_class,
                               federal_functional_class_descr =
                                   rec.federal_functional_class_descr
                         WHERE     element_id = rec.element_id
                                   AND snapshot_year = 2021
                           LOG ERRORS INTO CRASHES_ON_ROUTE_ERROR_LOG
                                   ('Fix FFC ' || SYSDATE)
                                   REJECT LIMIT 100;

                    cntr_updated := cntr_updated + 1;



            END LOOP;



           UPDATE complete_transportation_network
                           SET
                                WCSH_CODE = 'Y'
                         WHERE
                                   snapshot_year = 2021 and row_type = 'Element'
                                   AND ((route_number = '0003X' and begin_section_mp >= 102.26  and end_section_mp <= 103.46)  or (route_number = '0003W' and begin_section_mp >= 0.08  and end_section_mp <= 0.18 ))
                           LOG ERRORS INTO COMPLETE_NETWORK_ERROR_LOG
                                   ('Fix FFC ' || SYSDATE)
                                   REJECT LIMIT 100;


                       UPDATE crashes_on_route_2021
                       SET
                                WCSH_CODE = 'Y'
                         WHERE
                                   (route_number = '0003X' and begin_section_mp >= 102.26  and end_section_mp <= 103.46) or (route_number = '0003W' and begin_section_mp >= 0.08  and end_section_mp <= 0.18 )
                           LOG ERRORS INTO CRASHES_ON_ROUTE_ERROR_LOG
                                   ('Fix FFC ' || SYSDATE)
                                   REJECT LIMIT 100;



            commit;
       
    FOR s IN secids                          -- STILL NEED TO DO IN PRODUCTION
    LOOP
        
                    UPDATE sections_history sh
                       SET
                           sh.WCSH_CODE = s.WCSH_CODE
                     WHERE     sh.section_id = s.section_id
                               AND sh.snapshot_year = 2021
                       LOG ERRORS INTO sections_history_error_log
                               ('Fix 2021 Snapshot ' || SYSDATE)
                               REJECT LIMIT 100;

        UPDATE complete_transportation_network ctn         -- alternate routes
           SET ctn.WCSH_CODE = s.WCSH_CODE
         WHERE     ctn.section_id = s.section_id
               AND ctn.snapshot_year = 2021
               AND ctn.route_number NOT IN ('0003X', '0003W')
           LOG ERRORS INTO sections_history_error_log
                   ('Fix 2021 Snapshot ' || SYSDATE)
                   REJECT LIMIT 100;
    END LOOP;

    COMMIT;

   

              FOR nfc IN node_ffc_changes
              LOOP

                UPDATE crashes_on_route_2021
                    SET
                            federal_functional_class =
                                nfc.federal_functional_class,
                            federal_functional_class_descr =
                                nfc.federal_functional_class_descr
                      WHERE     node_id = nfc.node_id
                                AND snapshot_year = 2021
                                AND row_type = 'Node'
                        LOG ERRORS INTO CRASHES_ON_ROUTE_ERROR_LOG
                                ('Fix FFC ' || SYSDATE)
                                REJECT LIMIT 100;

  UPDATE complete_transportation_network -- still need to fix for production
                    SET
                            federal_functional_class =
                                nfc.federal_functional_class,
                            federal_functional_class_descr =
                                nfc.federal_functional_class_descr
                      WHERE     node_id = nfc.node_id
                                AND snapshot_year = 2021
                                AND row_type = 'Node'
                        LOG ERRORS INTO COMPLETE_NETWORK_ERROR_LOG
                                ('Fix FFC ' || SYSDATE)
                                REJECT LIMIT 100;
                 cntr_updated := cntr_updated + 1;

                 UPDATE nodes_history -- still need to fix for production
                    SET
                            federal_functional_class =
                                nfc.federal_functional_class,
                            federal_functional_class_descr =
                                nfc.federal_functional_class_descr
                      WHERE     node_id = nfc.node_id
                                AND snapshot_year = 2021
                        LOG ERRORS INTO NODES_ERROR_LOG
                                ('Fix FFC ' || SYSDATE)
                                REJECT LIMIT 100;
                 cntr_updated := cntr_updated + 1;

       END LOOP


    COMMIT;

    -- Check error logs

    SELECT COUNT (*) INTO serrlog_count FROM sections_history_error_log;

    IF serrlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in Sections error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         g_jobname,
                         g_owner,
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('sections_history_error_log',
                         'Invalid data - check error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

    SELECT COUNT (*) INTO serrlog_count FROM COMPLETE_NETWORK_ERROR_LOG;

    IF serrlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in COMPLETE_NETWORK_ERROR_LOG error log ';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         g_jobname,
                         g_owner,
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('COMPLETE_NETWORK_ERROR_LOG',
                         'Invalid data - check error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

    SELECT COUNT (*) INTO serrlog_count FROM CRASHES_ON_ROUTE_ERROR_LOG;

    IF serrlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in CRASHES_ON_ROUTE_ERROR_LOG';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         g_jobname,
                         g_owner,
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('CRASHES_ON_ROUTE_ERROR_LOG',
                         'Invalid data - check error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

    -- normal processing, ignoring quality errors

    SELECT COUNT (*) INTO cntr FROM sections_history;

    V_flat_file_counts_txt :=
           'SECTIONS: '
        || 'Total Rows: '
        || cntr
        || ' Added: '
        || cntr_added
        || ' Updated/New Row Added: '
        || cntr_updated
        || '  ';

    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
        OWNER         => G_OWNER,
        OBJECT_NAME   => g_object,
        object_cnt    => cntr,
        add_cnt       => cntr_added,
        update_cnt    => cntr_updated,
        proc          => $$PLSQL_UNIT,
        start_time    => g_start_time);

    wh_common.pkg_common_utilities.EXIT_AND_REPORT (g_jobname,
                                                    'NORMAL',
                                                    V_flat_file_counts_txt);


    COMMIT;
EXCEPTION
    WHEN OTHERS
    THEN
        G_SQLMSG := SUBSTR (SQLERRM, 1, 400);
        wh_common.pkg_common_utilities.update_whse_log (
            g_owner,
            g_object,
            NULL,
            NULL,
            NULL,
            NULL,
            'Error during ' || g_jobname || ': ' || G_SQLMSG,
            'Failed');
        wh_common.pkg_common_utilities.exit_and_report (
            g_jobname,
            'FAILURE',
            g_jobname || ' - ' || G_SQLMSG);
        RAISE_APPLICATION_ERROR (-20020, $$PLSQL_UNIT || ' ' || G_SQLMSG);
END;
/
