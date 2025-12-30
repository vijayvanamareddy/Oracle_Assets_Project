BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'RUN_PRC_COMPILER'
      ,start_date      => TO_TIMESTAMP_TZ('2015/07/03 09:00:00.000000 US/Eastern','yyyy/mm/dd hh24:mi:ss.ff tzr')
      ,repeat_interval => 'FREQ=DAILY;  BYHOUR= 7,19; BYMINUTE=30;BYSECOND=0'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'STORED_PROCEDURE'
      ,job_action      => 'WH_ASSETS.PRC_COMPILER'
      ,comments        => NULL
    );
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_PRC_COMPILER'
     ,attribute => 'RESTARTABLE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_PRC_COMPILER'
     ,attribute => 'LOGGING_LEVEL'
     ,value     => SYS.DBMS_SCHEDULER.LOGGING_OFF);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'RUN_PRC_COMPILER'
     ,attribute => 'MAX_FAILURES');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'RUN_PRC_COMPILER'
     ,attribute => 'MAX_RUNS');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_PRC_COMPILER'
     ,attribute => 'STOP_ON_WINDOW_CLOSE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_PRC_COMPILER'
     ,attribute => 'JOB_PRIORITY'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'RUN_PRC_COMPILER'
     ,attribute => 'SCHEDULE_LIMIT');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_PRC_COMPILER'
     ,attribute => 'AUTO_DROP'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_PRC_COMPILER'
     ,attribute => 'RESTART_ON_RECOVERY'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_PRC_COMPILER'
     ,attribute => 'RESTART_ON_FAILURE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_PRC_COMPILER'
     ,attribute => 'STORE_OUTPUT'
     ,value     => TRUE);

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'RUN_PRC_COMPILER');
END;
/
