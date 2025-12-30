CREATE OR REPLACE PROCEDURE PRC_FAUX_BACKUP  (parm_tbl in  varchar2 := NULL ) 
AS
     cursor email_recpts is 
        select * from wh_common.tbemailrecipients
         where upper(msg_severity) = 'NORMAL'   and upper(msg_jobsource) = 'COMPILES';

      
   cntr                     NUMBER := 0;   
   g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
   g_tablespace             VARCHAR2 (20) := 'WH_ASSETS_DATA';
   g_jobname                VARCHAR2 (30) := $$PLSQL_UNIT;
   g_start_time             DATE := sysdate;
   g_object                 VARCHAR2 (20)   := NULL;
   g_sqlmsg                 VARCHAR2(1000)  := NULL;
   v_txt  varchar2(4000) := 'Got to Faux Backup';
   status_summ varchar2(50);
   ix number(5);
   gname varchar2(20);
   sqlerm  varchar2(500) := NULL;
   
BEGIN
     select * into gname from global_name;
     
     wh_fact.pkg_email.p_email_message( 'PETER.DEVLIN@MAINE.GOV'
                , null 
                , 'FAUX BACKUP('||gname||')',
                v_txt );
 
     
     exception when others then 
 
             raise_application_error(-20003,
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
