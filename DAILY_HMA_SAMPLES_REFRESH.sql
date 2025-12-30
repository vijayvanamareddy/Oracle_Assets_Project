BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'DAILY_HMA_SAMPLES_REFRESH'
      ,start_date      => TO_TIMESTAMP_TZ('2024/12/06 06:00:00.000000 EST5EDT','yyyy/mm/dd hh24:mi:ss.ff tzr')
      ,repeat_interval => 'FREQ=DAILY;BYHOUR=6;BYMINUTE=00;BYSECOND=0'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'STORED_PROCEDURE'
      ,job_action      => 'WH_ASSETS.LOAD_HMA_SAMPLES_STAGING'
      ,comments        => 'Daily Update for HMA Samples'
    );
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DAILY_HMA_SAMPLES_REFRESH'
     ,attribute => 'RESTARTABLE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DAILY_HMA_SAMPLES_REFRESH'
     ,attribute => 'LOGGING_LEVEL'
     ,value     => SYS.DBMS_SCHEDULER.LOGGING_RUNS);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DAILY_HMA_SAMPLES_REFRESH'
     ,attribute => 'MAX_FAILURES');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DAILY_HMA_SAMPLES_REFRESH'
     ,attribute => 'MAX_RUNS');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DAILY_HMA_SAMPLES_REFRESH'
     ,attribute => 'STOP_ON_WINDOW_CLOSE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DAILY_HMA_SAMPLES_REFRESH'
     ,attribute => 'JOB_PRIORITY'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DAILY_HMA_SAMPLES_REFRESH'
     ,attribute => 'SCHEDULE_LIMIT');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DAILY_HMA_SAMPLES_REFRESH'
     ,attribute => 'AUTO_DROP'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DAILY_HMA_SAMPLES_REFRESH'
     ,attribute => 'RESTART_ON_RECOVERY'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DAILY_HMA_SAMPLES_REFRESH'
     ,attribute => 'RESTART_ON_FAILURE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DAILY_HMA_SAMPLES_REFRESH'
     ,attribute => 'STORE_OUTPUT'
     ,value     => TRUE);

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'DAILY_HMA_SAMPLES_REFRESH');
END;
/
