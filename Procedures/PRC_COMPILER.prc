CREATE OR REPLACE PROCEDURE PRC_COMPILER (parm_schema in  varchar2 := 'WH_ASSETS' ) 
/*          PD initial version
  
  
*/ 
AS
     cursor email_recpts is 
        select * from wh_common.tbemailrecipients
         where upper(msg_severity) = 'NORMAL'   and upper(msg_jobsource) = 'PRC_COMPILER';

     cursor compile_list is
              select * from ( 
             select       DECODE(object_type, 
               'FUNCTION',
               'ALTER FUNCTION '||OWNER||'.'||OBJECT_NAME||' COMPILE ',
               'VIEW',
               'ALTER VIEW '||OWNER||'.'||OBJECT_NAME||' COMPILE ',
               'PACKAGE',
               'ALTER PACKAGE '||OWNER||'.'||OBJECT_NAME||' COMPILE PACKAGE ',
               'PACKAGE BODY',
               'ALTER PACKAGE '||OWNER||'.'||OBJECT_NAME||' COMPILE BODY ',
               'PROCEDURE',
               'ALTER PROCEDURE '||OWNER||'.'||OBJECT_NAME||' COMPILE ',
               'MATERIALIZED VIEW',
               'ALTER MATERIALIZED VIEW '||OWNER||'.'||OBJECT_NAME||' COMPILE ',
               'TRIGGER',
               'ALTER TRIGGER '||OWNER||'.'||OBJECT_NAME||' COMPILE ',
               NULL)  RecompileSql
       FROM   dba_objects
       WHERE  status    = 'INVALID'   and owner = 'WH_ASSETS' and substr(object_name,1,2) <> 'Z_' 
         order by owner,object_name  ) where  RecompileSql is not null;  
   
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
   msg_txt varchar2(200);
   
BEGIN
     select * into gname from global_name;
     
     
     for rec in compile_list  loop
         begin
         dbms_output.put_line(rec.RecompileSql);
         execute immediate rec.RecompileSql;
         exception when others then NULL;
         end;
     end loop;
     
     select count(*) into ix from all_objects
        WHERE  status =  'INVALID'  and owner = 'WH_ASSETS' and substr(object_name,1,2) <> 'Z_' 
        ; --  and object_type = 'PROCEDURE';
          
     if ix > 0 then
        status_summ := 'Invalids Present in WH_ASSETS!';
        for rec in compile_list  loop
         msg_txt := replace(rec.RecompileSql,'ALTER');
         msg_txt := replace(msg_txt,'COMPILE');
         msg_txt := replace(msg_txt,'BODY');
         v_txt := v_txt || msg_txt ||chr(9)||chr(10);
        end loop;
    -- else
       -- status_summ := 'All packages are valid!';
       -- v_txt := 'No invalid packages found in warehouse';
     end if;
     
     for rec in email_recpts loop
         wh_fact.pkg_email.p_email_message( rec.msg_emailaddr
                , null 
                , 'Warehouse('||gname||')'||' Package Status: '||status_summ,
                v_txt );
      end loop;  
      WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG 
               (OWNER => G_OWNER, OBJECT_NAME => g_object,
                PROC => $$PLSQL_UNIT, start_time => g_start_time);  
      commit;
      exception when others then 
             WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG 
               (OWNER => G_OWNER, OBJECT_NAME => g_object,
                PROC => $$PLSQL_UNIT, start_time => g_start_time, STATUS => 'Failure',
                MSG => SUBSTR(SQLERRM,1,400) );    
             wh_common.pkg_common_utilities.exit_and_report
                 ($$PLSQL_UNIT,
                  'FAILURE',
                  'Error during '||$$PLSQL_UNIT||': '||SUBSTR(SQLERRM,1,400));  
             raise_application_error(-20001,
                  'Error in '||$$PLSQL_UNIT||': '||SUBSTR(SQLERRM,1,400));
       
END;
/
