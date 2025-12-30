BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'IBRIDGES_WEEKDAY_REFRESH'
      ,start_date      => TO_TIMESTAMP_TZ('2016/06/23 09:15:00.000000 -05:00','yyyy/mm/dd hh24:mi:ss.ff tzr')
      ,repeat_interval => 'FREQ=DAILY; BYDAY=MON,TUE,WED,THU,FRI; BYHOUR=1; BYMINUTE=0;BYSECOND=0'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'STORED_PROCEDURE'
      ,job_action      => 'IBRIDGES_DAILY_REFRESH'
      ,comments        => NULL
    );
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'IBRIDGES_WEEKDAY_REFRESH'
     ,attribute => 'RESTARTABLE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'IBRIDGES_WEEKDAY_REFRESH'
     ,attribute => 'LOGGING_LEVEL'
     ,value     => SYS.DBMS_SCHEDULER.LOGGING_OFF);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'IBRIDGES_WEEKDAY_REFRESH'
     ,attribute => 'MAX_FAILURES');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'IBRIDGES_WEEKDAY_REFRESH'
     ,attribute => 'MAX_RUNS');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'IBRIDGES_WEEKDAY_REFRESH'
     ,attribute => 'STOP_ON_WINDOW_CLOSE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'IBRIDGES_WEEKDAY_REFRESH'
     ,attribute => 'JOB_PRIORITY'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'IBRIDGES_WEEKDAY_REFRESH'
     ,attribute => 'SCHEDULE_LIMIT');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'IBRIDGES_WEEKDAY_REFRESH'
     ,attribute => 'AUTO_DROP'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'IBRIDGES_WEEKDAY_REFRESH'
     ,attribute => 'RESTART_ON_RECOVERY'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'IBRIDGES_WEEKDAY_REFRESH'
     ,attribute => 'RESTART_ON_FAILURE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'IBRIDGES_WEEKDAY_REFRESH'
     ,attribute => 'STORE_OUTPUT'
     ,value     => TRUE);

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'IBRIDGES_WEEKDAY_REFRESH');
END;
/
