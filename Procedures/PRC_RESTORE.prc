CREATE OR REPLACE PROCEDURE PRC_RESTORE  (parm_tbl in  varchar2 := NULL ) 
-- 4/30/2019 SH Change dba_tables to user_tables for 12c deployment
AS
     cursor email_recpts is 
        select * from wh_common.tbemailrecipients
         where upper(msg_severity) = 'NORMAL'   and upper(msg_jobsource) = 'COMPILES';

     cursor standard_table_list is
        select upper(table_name) table_name from STANDARD_ASSET_CYCLE_BKPS;
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
           select count(*) into cntr from user_tables where table_name = 'BKP_'||rec.table_name;
           if cntr > 0 then
               execute immediate 'truncate table'||rec.table_name ;
               execute immediate 'insert into '||rec.table_name|| '  select * from BKP_'||rec.table_name ; 
               commit;
           else
               WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (OWNER => G_OWNER, OBJECT_NAME => g_object,
                 proc => $$PLSQL_UNIT, start_time => g_start_time, status => 'Failure',
                 msg => 'Invalid Table Name ('||rec.table_name||') in STANDARD_ASSET_CYCLE_BKPS' );    
               wh_common.pkg_common_utilities.exit_and_report($$PLSQL_UNIT,
                                      'FAILURE',
                                      'Invalid Table Name ('||rec.table_name||') in STANDARD_ASSET_CYCLE_BKPS');
               raise_application_error(-20003,
                                      'Invalid Table Name ('||rec.table_name||') in STANDARD_ASSET_CYCLE_BKPS');
           end if;
        end loop;         
     else
           select count(*) into cntr from user_tables where table_name = 'BKP_'||upper(parm_tbl);
           if cntr > 0 then
               execute immediate 'truncate table'||parm_tbl ;
               execute immediate 'insert into '||parm_tbl|| '  select * from BKP_'||parm_tbl ; 
               commit;
           else
               WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (OWNER => G_OWNER, OBJECT_NAME => g_object,
                 proc => $$PLSQL_UNIT, start_time => g_start_time, status => 'Failure',
                 msg => 'Table Name in parm is not valid' );    
               wh_common.pkg_common_utilities.exit_and_report($$PLSQL_UNIT,
                                      'FAILURE',
                                      'Error during '||$$PLSQL_UNIT||': Table Name in parm is not valid');
               raise_application_error(-20002,
                                      'Error during '||$$PLSQL_UNIT||': Table Name in parm is not valid');
           end if;
            
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
