CREATE OR REPLACE PROCEDURE monitor_bridge_number
IS

  /**********************************************************************
    This procedure checks the data_exceptions table and generates a report when
    an invalid bridge number is entered (> 4 characters)
    
    02-28-19  SH  Initial Version
    03-27-19  SH  Moved from dev to test
    ********************************/
  err_msg VARCHAR2( 400 );
  cntr   number(7) := 0;
  descr  varchar2(100) := NULL;
  
  cursor invalid_bridge is 
  SELECT column_value1 as bridge_number, test_date FROM data_exceptions WHERE 
  table_name = 'IBRIDGES_STAGING'
  AND ERROR_CONDITION = 'BRIDGE NUMBER TOO LONG' 
  AND to_char(test_date, 'MM/DD/YYYY') IN (select to_char(max(test_date), 'MM/DD/YYYY') from data_exceptions) ;

  

BEGIN
 for rec in invalid_bridge loop
        WH_COMMON.POST_TO_ALERT_LOG(  'ALERT13','WH_ASSETS',$$PLSQL_UNIT,
           'Bridge Number: ' || rec.bridge_number|| ' is in InspectTech but not inserted into the Data Warehouse on: ' || rec.test_date); 
 end loop;
   commit;   
   
 

 EXCEPTION
  WHEN OTHERS THEN
    err_msg := SUBSTR( SQLERRM, 1, 350 );
    INSERT INTO WH_COMMON.tberrlog 
      ( err_datetime, err_oid, err_module, err_message )
    VALUES
      ( SYSDATE, USER, 'monitor_bridge_number', 'Unexpected failure: '||err_msg );
    COMMIT;
        wh_fact.pkg_email.p_email_message
          ( recipient => 'susan.hillson@maine.gov'
          , subject => 'monitor_bridge_number Has Failed'
          , bodyText => 'An unexpected failure has occurred: '||err_msg
            ||CHR(10)||CHR(13)||CHR(10)||CHR(13)|| ' '||TO_CHAR( SYSDATE, 'MM/DD/YYYY HH24:MI:SS' ) );        
END;
/
