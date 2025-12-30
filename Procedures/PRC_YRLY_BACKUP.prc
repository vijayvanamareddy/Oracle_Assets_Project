CREATE OR REPLACE PROCEDURE PRC_YRLY_BACKUP  
AS
 /*********************************************************************************************************
   This procedure backs up the history tables prior to creating the yearly snapshots
 
   It is run once a year.  The backup files can be deleted once it is determined the freeze has been successful.
   The tables that are backed up are in the table, standard_asset_cycle_bkps
   
   The backups are named, tablename_snapshotyear, like SECTIONS_HISTORY_2019
   If run multiple times, the backup will be named SECTIONS_HISTORY_2019_1, SECTIONS_HISTORY_2019_2
   
   3/22/2016  SH  Initial version, copy of PRC_BACKUP written by P. Devlin
   2/14/2019  SH  Get snapshot year from element_history instead of highways_history
   4/30/2019  SH  Change dba_tables to user_tables for 12C deployment
   5/29/2019  SH  Do not backup ACCIDENT tables as they don't need a yearly snapshot
   10/1/2019  SH  Rather than drop the backup file, create one with a different name, to help avoid user error of running procedure multiple times
   **********************************************************************************************************/
   
   
  
     cursor standard_table_list is
        select upper(table_name) table_name from standard_asset_cycle_bkps where table_name not like 'ACCIDENT%';
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
   yr   NUMBER;
   
BEGIN
     select * into gname from global_name;
     select max(snapshot_year) into yr from element_history;
   
        for rec in standard_table_list loop
           select count(*) into cntr from user_tables where table_name like rec.table_name||'_'||TO_CHAR(yr)||'%';
           if cntr > 0 then  -- if we already have a backup for the year, create one with _ cntr
--              execute immediate 'drop table ' || rec.table_name||'_'||TO_CHAR(yr) || ' purge';
                execute immediate 'create table ' || rec.table_name||'_'||TO_CHAR(yr) || '_' || cntr || ' tablespace '||g_tablespace||
                ' as select * from '||rec.table_name ; 
           else
             execute immediate 'create table ' || rec.table_name||'_'||TO_CHAR(yr) || ' tablespace '||g_tablespace||
                ' as select * from '||rec.table_name ; 
           end if;
        end loop;         
    
  
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
/
