CREATE OR REPLACE PROCEDURE PRC_BACKUP  (parm_tbl in  varchar2 := NULL ) 
/*          PD initial version
   03-27-19 SH Check owner of table from DBA_TABLES
   05-01-19 SH Change DBA_TABLES to USER_TABLES in preparation for 12C deployment
   01-26-22 SH Add comments to the BKP files
*/   
AS
     cursor email_recpts is 
        select * from wh_common.tbemailrecipients
         where upper(msg_severity) = 'NORMAL'   and upper(msg_jobsource) = 'COMPILES';

     cursor standard_table_list is
        select upper(table_name) table_name from standard_asset_cycle_bkps;
   cntr                     NUMBER := 0;   
   g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
   g_tablespace             VARCHAR2 (20) := 'WH_ASSETS_DATA';
   g_jobname                VARCHAR2 (30) := $$PLSQL_UNIT;
   g_start_time             DATE := sysdate;
   g_object                 VARCHAR2 (20)   := NULL;
   g_sqlmsg                 VARCHAR2(1000)  := NULL;
   v_txt  varchar2(4000) := NULL;
   status_summ varchar2(50);
   ix number(5);
   gname varchar2(20);
   sqlerm  varchar2(500) := NULL;
   
BEGIN
     select * into gname from global_name;
     if parm_tbl is null then
        for rec in standard_table_list loop
           select count(*) into cntr from user_tables where  table_name = 'BKP_'||rec.table_name;
           if cntr > 0 then
               execute immediate 'drop table BKP_'||rec.table_name||' purge ';
           end if;
           execute immediate 'create table BKP_'||rec.table_name||' tablespace '||g_tablespace||
              ' as select * from '||rec.table_name ; 
           execute immediate 'COMMENT ON TABLE BKP_'||rec.table_name||' IS 
              ''Backup prior to weekly refresh of table'' ' ; 
        end loop;         
     else
           select count(*) into cntr from user_tables where table_name = 'BKP_'||upper(parm_tbl);
           if cntr > 0 then
               execute immediate 'drop table BKP_'||parm_tbl||' purge ';
           end if;
           execute immediate 'create table BKP_'||upper(parm_tbl)||' tablespace '||g_tablespace||
              ' as select * from '||upper(parm_tbl) ;  
      end if;
     
     exception when others then 
             WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (OWNER => G_OWNER, OBJECT_NAME => g_object,
                 proc => $$PLSQL_UNIT, start_time => g_start_time, status => 'Failure',
                 msg => SUBSTR(SQLERRM,1,400) );    
             wh_common.pkg_common_utilities.exit_and_report($$PLSQL_UNIT,
                                      'FAILURE',
                                      'Error during '||$$PLSQL_UNIT||': '||SUBSTR(SQLERRM,1,400));  
             raise_application_error(-20000,
                                     'Error during '||$$PLSQL_UNIT||': '||SUBSTR(SQLERRM,1,400));
         end;

--
--     for rec in email_recpts loop
--         wh_fact.pkg_email.p_email_message( rec.msg_emailaddr
--                , null 
--                , 'Warehouse('||gname||')'||' Package Status: '||status_summ,
--                v_txt );
--      end loop;
/
