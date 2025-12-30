BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'ACCIDENTS_DAILY_REFRESH'
      ,start_date      => TO_TIMESTAMP_TZ('2019/09/20 02:00:00.000000 -04:00','yyyy/mm/dd hh24:mi:ss.ff tzr')
      ,repeat_interval => 'FREQ=DAILY; BYDAY=TUE,WED,THU, FRI; BYHOUR=2; BYMINUTE=0;BYSECOND=0'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'STORED_PROCEDURE'
      ,job_action      => 'CRASH_DAILY_REFRESH'
      ,comments        => NULL
    );
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'ACCIDENTS_DAILY_REFRESH'
     ,attribute => 'RESTARTABLE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'ACCIDENTS_DAILY_REFRESH'
     ,attribute => 'LOGGING_LEVEL'
     ,value     => SYS.DBMS_SCHEDULER.LOGGING_OFF);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'ACCIDENTS_DAILY_REFRESH'
     ,attribute => 'MAX_FAILURES');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'ACCIDENTS_DAILY_REFRESH'
     ,attribute => 'MAX_RUNS');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'ACCIDENTS_DAILY_REFRESH'
     ,attribute => 'STOP_ON_WINDOW_CLOSE'
     ,value     => TRUE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'ACCIDENTS_DAILY_REFRESH'
     ,attribute => 'JOB_PRIORITY'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'ACCIDENTS_DAILY_REFRESH'
     ,attribute => 'SCHEDULE_LIMIT');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'ACCIDENTS_DAILY_REFRESH'
     ,attribute => 'AUTO_DROP'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'ACCIDENTS_DAILY_REFRESH'
     ,attribute => 'RESTART_ON_RECOVERY'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'ACCIDENTS_DAILY_REFRESH'
     ,attribute => 'RESTART_ON_FAILURE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'ACCIDENTS_DAILY_REFRESH'
     ,attribute => 'STORE_OUTPUT'
     ,value     => TRUE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'ACCIDENTS_DAILY_REFRESH'
     ,attribute => 'MAX_RUN_DURATION'
     ,value     => TO_DSINTERVAL('+000 03:00:00'));

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'ACCIDENTS_DAILY_REFRESH');
END;
/
