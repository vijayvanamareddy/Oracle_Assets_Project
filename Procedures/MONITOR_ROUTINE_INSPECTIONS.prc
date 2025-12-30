CREATE OR REPLACE PROCEDURE monitor_routine_inspections
IS

  /**********************************************************************
    This procedure compares the 2 sources for the last routine inspection date
    which come from InspectTech.  
       a.  The column inspection_date comes from InspectTech current values table and is NBI 90.  
       b.  The column, last_routine_inspection_date comes from the InspectTech inspection records.
    
    When the dates are not the same, they are posted to the alert log, with a code of ALERT11.
    
    05-19-2017  SH  Initial Version
    11-25-18 SH Change references of ibridges to ibridges_history WHERE end_date is NULL to facilitate change to new bridge selection criteria  
    ********************************/
  err_msg VARCHAR2( 400 );
  cntr   number(7) := 0;
  descr  varchar2(100) := NULL;
  
  cursor inspection_mismatch is 
      select bridge_number, inspection_date nbi90, last_routine_inspection_date from ibridges_history
      where end_date IS NULL AND inspection_date <> last_routine_inspection_date order by 1;

BEGIN
 for rec in inspection_mismatch loop
        WH_COMMON.POST_TO_ALERT_LOG(  'ALERT11','WH_ASSETS',$$PLSQL_UNIT,
           'The latest routine inspection dates do not match for bridge: '|| rec.bridge_number||' NBI 90 Date: '|| rec.NBI90 || ' Last approved inspection Date: ' || rec.last_routine_inspection_date );
 end loop;
   commit;   
 EXCEPTION
  WHEN OTHERS THEN
    err_msg := SUBSTR( SQLERRM, 1, 350 );
    INSERT INTO WH_COMMON.tberrlog 
      ( err_datetime, err_oid, err_module, err_message )
    VALUES
      ( SYSDATE, USER, 'monitor_routine_inspections', 'Unexpected failure: '||err_msg );
    COMMIT;
        wh_fact.pkg_email.p_email_message
          ( recipient => 'susan.hillson@maine.gov'
          , subject => 'monitor_routine_inspections Has Failed'
          , bodyText => 'An unexpected failure has occurred: '||err_msg
            ||CHR(10)||CHR(13)||CHR(10)||CHR(13)|| ' '||TO_CHAR( SYSDATE, 'MM/DD/YYYY HH24:MI:SS' ) );        
END;
/
