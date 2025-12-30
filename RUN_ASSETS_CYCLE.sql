BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'RUN_ASSETS_CYCLE'
      ,start_date      => TO_TIMESTAMP_TZ('2020/12/12 21:00:00.000000 US/Eastern','yyyy/mm/dd hh24:mi:ss.ff tzr')
      ,repeat_interval => 'FREQ= WEEKLY;BYHOUR=21;BYMINUTE=00;BYSECOND=0'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'STORED_PROCEDURE'
      ,job_action      => 'WH_ASSETS.CONTROL_ASSETS_CYCLE'
      ,comments        => NULL
    );
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_ASSETS_CYCLE'
     ,attribute => 'RESTARTABLE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_ASSETS_CYCLE'
     ,attribute => 'LOGGING_LEVEL'
     ,value     => SYS.DBMS_SCHEDULER.LOGGING_OFF);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'RUN_ASSETS_CYCLE'
     ,attribute => 'MAX_FAILURES');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'RUN_ASSETS_CYCLE'
     ,attribute => 'MAX_RUNS');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_ASSETS_CYCLE'
     ,attribute => 'STOP_ON_WINDOW_CLOSE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_ASSETS_CYCLE'
     ,attribute => 'JOB_PRIORITY'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'RUN_ASSETS_CYCLE'
     ,attribute => 'SCHEDULE_LIMIT');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_ASSETS_CYCLE'
     ,attribute => 'AUTO_DROP'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_ASSETS_CYCLE'
     ,attribute => 'RESTART_ON_RECOVERY'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_ASSETS_CYCLE'
     ,attribute => 'RESTART_ON_FAILURE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'RUN_ASSETS_CYCLE'
     ,attribute => 'STORE_OUTPUT'
     ,value     => TRUE);

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'RUN_ASSETS_CYCLE');
END;
/
