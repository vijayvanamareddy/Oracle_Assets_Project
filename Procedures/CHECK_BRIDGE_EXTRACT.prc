CREATE OR REPLACE PROCEDURE check_bridge_extract
IS
/**********************************************************************
This procedure checks the bridge extract from Assetwise
It checks for the following:

        1. Are there any bad files
        2. Are there any zero length files
        3. Are the CSV files up to date

The bridge data is extracted from Assetwise nightly, and written to csv files in the directory
EXT_DIR_FTPROOT '/mdot_ftproot_dev' .

At the end of the extract, a batch job is run to create a directory listing in the file, files.txt
The external table, ext_files reads that file.

If an error occurs, it is logged in the data_exceptions table, and wh_common.tberrlog

04-26-2021 SH - Initial Version

**********************************************************************/

BEGIN
    DECLARE
        tab                     VARCHAR2 (30):= 'BRIDGES' ;
        test_procedure          VARCHAR2 (30) := 'CHECK_BRIDGE_EXTRACT';
        rundate                 DATE := SYSDATE;
        col_name1               VARCHAR2 (30) := 'BRIDGES';
        col_val1                VARCHAR2 (30);
        col_name2               VARCHAR2 (30);
        col_val2                VARCHAR2 (30);
        col_name3               VARCHAR2 (30);
        col_val3                VARCHAR2 (30);
        col_name4               VARCHAR2 (30);
        col_val4                VARCHAR2 (30);
        tname                   VARCHAR2 (100);
        assess                  VARCHAR2 (10);
        err_msg                 VARCHAR2 (100);
        cntr                    NUMBER := 0;
        cntr_added              NUMBER := 0;
        start_time              DATE := SYSDATE;

        bad_file_cntr           NUMBER;
        zero_length_file_cntr   NUMBER;
        file_age_cntr           NUMBER;
        days_back               NUMBER := 2;


        PROCEDURE Write_it (p1    IN VARCHAR,
                            p2    IN VARCHAR,
                            p3    IN NUMBER,
                            p4    IN VARCHAR,
                            p5    IN VARCHAR,
                            p6    IN VARCHAR,
                            p7    IN VARCHAR,
                            p8    IN VARCHAR,
                            p9    IN VARCHAR,
                            p10   IN VARCHAR,
                            p11   IN VARCHAR,
                            p12   IN VARCHAR,
                            p13   IN VARCHAR,
                            p14   IN VARCHAR,
                            p15   IN DATE,
                            p16   IN VARCHAR)
        IS
        BEGIN
            INSERT INTO data_exceptions (TABLE_NAME,
                                         ASSET_ID_COLUMN,
                                         ASSET_ID,
                                         ERROR_CONDITION,
                                         COLUMN_NAME1,
                                         COLUMN_VALUE1,
                                         COLUMN_NAME2,
                                         COLUMN_VALUE2,
                                         COLUMN_NAME3,
                                         COLUMN_VALUE3,
                                         COLUMN_NAME4,
                                         COLUMN_VALUE4,
                                         TEST_NAME,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES (p1,
                         p2,
                         p3,
                         p4,
                         p5,
                         p6,
                         p7,
                         p8,
                         p9,
                         p10,
                         p11,
                         p12,
                         p13,
                         p14,
                         p15,
                         p16);

            cntr_added := cntr_added + 1;
        END;
    BEGIN
        SELECT COUNT (*)
          INTO bad_file_cntr
          FROM ext_files
         WHERE file_name LIKE '%.bad';

        IF bad_file_cntr <> 0
        THEN
            col_val1 := 'Bad Files';
            Write_it (tab,
                      NULL,
                      NULL,
                      err_msg,
                      col_name1,
                      col_val1,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      tname,
                      test_procedure,
                      rundate,
                      assess);
        END IF;

        SELECT COUNT (*)
          INTO zero_length_file_cntr
          FROM ext_files
         WHERE     convert_to_number (REPLACE (file_size, ',', '')) = 0
               AND file_name LIKE '%.csv'
               AND file_name NOT LIKE 'SITS%';


        IF zero_length_file_cntr <> 0
        THEN
            col_val1 := 'ZERO LENGTH FILE';
            Write_it (tab,
                      NULL,
                      NULL,
                      err_msg,
                      col_name1,
                      col_val1,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      tname,
                      test_procedure,
                      rundate,
                      assess);
        END IF;

        SELECT COUNT (*)
          INTO file_age_cntr
          FROM EXT_files
         WHERE     file_name LIKE '%.csv'
               AND file_name NOT LIKE 'SITS%'
               AND   TRUNC (SYSDATE)
                   - CONVERT_to_date (SUBSTR (file_date, 1, 10),
                                      'MM/DD/YYYY') >
                   days_back;

        IF file_age_cntr <> 0
        THEN
            col_val1 := 'FILE AGE';
            Write_it (tab,
                      NULL,
                      NULL,
                      err_msg,
                      col_name1,
                      col_val1,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      NULL,
                      tname,
                      test_procedure,
                      rundate,
                      assess);
        END IF;

        COMMIT;



        SELECT COUNT (*)
          INTO cntr
          FROM data_exceptions
         WHERE     test_procedure = 'CHECK_BRIDGE_EXTRACT'
               AND test_date = rundate;



        IF cntr > 0
        THEN
            BEGIN
                err_msg :=
                    'Unexpected Issues in BRIDGE Extract Files';

                INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                                ERR_MODULE,
                                                ERR_OID,
                                                ERR_MESSAGE)
                     VALUES (SYSDATE,
                             'CHECK_BRIDGE_EXTRACT',
                             'WH_ASSETS',
                             err_msg);
            END;
        END IF;

        WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
            OWNER         => 'WH_ASSETS',
            OBJECT_NAME   => 'DATA_EXCEPTIONS',
            object_cnt    => cntr,
            add_cnt       => cntr_added,
            proc          => $$PLSQL_UNIT,
            start_time    => start_time);
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
                -20010,
                $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
    END;
END;
/
