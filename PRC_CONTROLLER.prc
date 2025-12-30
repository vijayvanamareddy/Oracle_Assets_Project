CREATE OR REPLACE PROCEDURE PRC_CONTROLLER (parm_schema in  varchar2 := 'WH_ASSETS' ) 
AS
     cursor email_recpts is 
        select * from wh_common.tbemailrecipients
         where upper(msg_severity) = 'NORMAL'   and upper(msg_jobsource) = 'COMPILES';
 
   
   g_owner                  VARCHAR2 (20) := 'WH_ASSETS';
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
 
      prc_compiler;
      
      prc_faux_backup;
      
      prc_compiler;

  
      exception when others then 
  
             raise_application_error(-20004,
                  'Error in '||$$PLSQL_UNIT||': '||SUBSTR(SQLERRM,1,400));
       
END;
/
