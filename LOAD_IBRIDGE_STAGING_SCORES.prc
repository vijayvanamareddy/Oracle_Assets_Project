CREATE OR REPLACE PROCEDURE load_ibridge_staging_scores
IS
   /**********************************************************************
   This procedure loads the ibridges staging table with the bridge scores from the
   gisdev database
   
   6-13-16 SH Initial version, copy from load_bridge_scores
   7-11-16 SH Add standard error handling
   11-16-16 SH Modify dblink to point to GIS production (from csl_bridges@gisdev to csl_bridges@gis)
   ************************************************************************************/

   cntr         NUMBER := 0;
   start_time   DATE := SYSDATE;
BEGIN
   

   UPDATE ibridges_staging b
      SET (bridge_condition_score,
           bridge_posting_score,
           bridge_reliability_score,
           score_date) =
             (SELECT strcbrdg,
                     brdgpst,
                     brdgrel,
                     date_mod
                FROM medot.csl_bridges@gis c
               WHERE b.bridge_number = c.brdgno)
      LOG ERRORS INTO ibridges_history_error_log ('Load bridges staging score data ' || SYSDATE)
             REJECT LIMIT UNLIMITED;

   COMMIT;

   SELECT COUNT (*) INTO cntr FROM ibridges_staging;

   WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
      OWNER         => 'WH_ASSETS',
      OBJECT_NAME   => 'IBRIDGES_STAGING',
      object_cnt    => cntr,
      proc          => $$PLSQL_UNIT,
      start_time    => start_time);
      
   COMMIT;

EXCEPTION
   WHEN OTHERS
   THEN
      wh_common.pkg_common_utilities.update_whse_log (
         'WH_ASSETS',
         $$PLSQL_UNIT,
         NULL,
         NULL,
         NULL,
         NULL,
            'Error during '
         || $$PLSQL_UNIT
         || ' Line:'
         || $$PLSQL_LINE
         || ': '
         || SUBSTR (SQLERRM, 1, 400),
         'Failed');
      wh_common.pkg_common_utilities.exit_and_report (
         $$PLSQL_UNIT,
         'FAILURE',
         'Error during ' || $$PLSQL_UNIT || ': ' || SUBSTR (SQLERRM, 1, 400));
      RAISE_APPLICATION_ERROR (
         -20050,
         $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
END;
/
