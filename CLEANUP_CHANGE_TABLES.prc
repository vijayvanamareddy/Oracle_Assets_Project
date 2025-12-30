CREATE OR REPLACE PROCEDURE CLEANUP_CHANGE_TABLES
AS
/**********************************************************************
      This procedure will delete rows from the change tables and data_exceptions table
      older than 90 days.
      
      It gets the names of the change tables from the table change_tables
      
      It can be run at snapshot time or more frequently
      
      04-10-23 SH Initial Version
  */
    delete_cnt               NUMBER;
    cnt                      NUMBER;
    g_start_time             DATE := SYSDATE;
    ierrlog                  NUMBER;
    rrerrlog                 NUMBER;
    rerrlog                  NUMBER;
    err_log_message          VARCHAR2 (200) := NULL;
    g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
    g_object                 VARCHAR2 (50);
    V_flat_file_counts_txt   VARCHAR2 (1000) := NULL;

   
    CURSOR cleanup_tables IS
        SELECT UPPER (table_name) table_name FROM change_tables;
BEGIN
   
    FOR rec IN cleanup_tables
    LOOP
        g_object := rec.table_name;  
      

        EXECUTE IMMEDIATE 'select count(*)  from ' || rec.table_name INTO CNT;
        
        EXECUTE IMMEDIATE   'select count(*) from '
                         || rec.table_name || ' WHERE CHANGE_DATE <= SYSDATE - 90' 
                          into delete_cnt;     

        EXECUTE IMMEDIATE   'delete from '
                         || rec.table_name
                         || ' where CHANGE_DATE <=  SYSDATE - 90';
                         
        WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
            OWNER         => G_OWNER,
            OBJECT_NAME   => g_object,
            object_cnt    => cnt,
            UPDATE_CNT    => delete_cnt,
            proc          => $$PLSQL_UNIT,
            start_time    => g_start_time);
        COMMIT;
    END LOOP;
    
    -- Clean up data exceptions
    g_object := 'DATA_EXCEPTIONS';
    select count(*) into cnt from data_exceptions;
    select count(*) into delete_cnt from data_exceptions  WHERE TEST_DATE <= SYSDATE - 90;
    DELETE  from data_exceptions  WHERE TEST_DATE <= SYSDATE - 90;
    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
            OWNER         => G_OWNER,
            OBJECT_NAME   => g_object,
            object_cnt    => cnt,
            UPDATE_CNT    => delete_cnt,
            proc          => $$PLSQL_UNIT,
            start_time    => g_start_time);
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
      
END;
/
