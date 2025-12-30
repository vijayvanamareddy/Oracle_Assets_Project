CREATE OR REPLACE PROCEDURE PRC_COMPILER_Once
AS
     cursor email_recpts is 
        select * from wh_common.tbemailrecipients
         where upper(msg_severity) = 'NORMAL'   and upper(msg_jobsource) = 'PRC_COMPILER';

     cursor compile_list  is
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
       WHERE  status    = 'INVALID'   and owner  like 'WH_ASSETS%' 
         order by owner,object_name  ) where  RecompileSql is not null;
         
   v_txt  varchar2(4000) := NULL;
   status_summ varchar2(50);
   ix number(5);
   gname varchar2(20);
  
BEGIN
     select * into gname from global_name;
      
     
     for rec in compile_list  loop
         begin
         dbms_output.put_line(rec.RecompileSql);
         execute immediate rec.RecompileSql;
         exception when others then 
            dbms_output.put_line(to_char(sqlcode)||' '||substr(sqlerrm,1,60) );
         end;
     end loop;
     
     select count(*) into ix from dba_objects
        WHERE  status =  'INVALID'  and owner  like 'WH_ASSETS%'; 
          
          
     if ix > 0 then
        status_summ := ' Invalids Present in WH_ASSETS!';
        for rec in compile_list  loop
         v_txt := v_txt || rec.RecompileSql || chr(10);
        end loop;
     --else
      --  status_summ := 'All packages are valid in WH_COMMON!';
      --  v_txt := 'No invalid packages found in FACT2 warehouse';
     end if;
     
     if ix > 0 then
      for rec1 in email_recpts loop
         wh_fact.pkg_email.p_email_message( rec1.msg_emailaddr
                , null 
                , 'Warehouse('||gname||')'||status_summ,
                v_txt );
     end loop;  
     end if; 
    
END;
/
