BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'RECYCLE_BIN_CLEANUP'
      ,start_date      => TO_TIMESTAMP_TZ('2024/05/01 01:00:00.000000 -04:00','yyyy/mm/dd hh24:mi:ss.ff tzr')
      ,repeat_interval => 'FREQ=DAILY;BYMONTHDAY=1'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'STORED_PROCEDURE'
      ,job_action      => 'WH_ASSETS.PURGE_TS_RECYCLE_BIN'
      ,comments        => 'Purges recycle bin freeing space'
    );
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RECYCLE_BIN_CLEANUP'
     ,attribute => 'RESTARTABLE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RECYCLE_BIN_CLEANUP'
     ,attribute => 'LOGGING_LEVEL'
     ,value     => SYS.DBMS_SCHEDULER.LOGGING_OFF);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'RECYCLE_BIN_CLEANUP'
     ,attribute => 'MAX_FAILURES');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'RECYCLE_BIN_CLEANUP'
     ,attribute => 'MAX_RUNS');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RECYCLE_BIN_CLEANUP'
     ,attribute => 'STOP_ON_WINDOW_CLOSE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RECYCLE_BIN_CLEANUP'
     ,attribute => 'JOB_PRIORITY'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'RECYCLE_BIN_CLEANUP'
     ,attribute => 'SCHEDULE_LIMIT');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RECYCLE_BIN_CLEANUP'
     ,attribute => 'AUTO_DROP'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RECYCLE_BIN_CLEANUP'
     ,attribute => 'RESTART_ON_RECOVERY'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RECYCLE_BIN_CLEANUP'
     ,attribute => 'RESTART_ON_FAILURE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RECYCLE_BIN_CLEANUP'
     ,attribute => 'STORE_OUTPUT'
     ,value     => TRUE);

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'RECYCLE_BIN_CLEANUP');
END;
/
