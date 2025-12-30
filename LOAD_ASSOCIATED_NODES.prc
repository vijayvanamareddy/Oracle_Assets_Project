CREATE OR REPLACE PROCEDURE load_associated_nodes
IS
   /**********************************************************************
   This procedure loads the associated_nodes_table from CRASH
   It does a complete refresh each time

   08-24-17   SH - Initial Version
   **********************************************************************/


 
   commit_count               NUMBER (7) := 0;
   cntr                       NUMBER (7) := 0;

   g_start_time               DATE := SYSDATE;
   g_owner                    VARCHAR2 (20) := 'WH_ASSETS';
   g_jobname                  VARCHAR2 (30) := 'LOAD_ASSOCIATED_NODES';
   g_object                   VARCHAR2 (20) := 'ASSOCIATED_NODES';
   g_sqlmsg                   VARCHAR2 (500) := NULL;

   CURSOR nod
   IS
      SELECT primarynode,associatednode FROM associatednodes@crash;
BEGIN
  

   EXECUTE IMMEDIATE 'TRUNCATE TABLE associated_nodes';
   EXECUTE IMMEDIATE 'TRUNCATE TABLE associated_nodes_error_log';

   FOR n IN nod
   LOOP
      

      INSERT INTO associated_nodes (primary_node_id,associated_node_id)
      VALUES (n.primarynode,n.associatednode)
      LOG ERRORS INTO associated_nodes_error_log ('Insert Associated Nodes ' || SYSDATE)
      REJECT LIMIT 100;

      commit_count := commit_count + 1;

      IF commit_count > 1000
      THEN
         COMMIT;
         commit_count := 0;
      END IF;
   END LOOP;

   COMMIT;


   SELECT COUNT (*) INTO cntr FROM associated_nodes;

   WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
      OWNER         => G_OWNER,
      OBJECT_NAME   => g_object,
      object_cnt    => cntr,
      proc          => $$PLSQL_UNIT,
      start_time    => g_start_time);
EXCEPTION
   WHEN OTHERS
   THEN
      G_SQLMSG := $$PLSQL_UNIT || ': ' || SUBSTR (SQLERRM, 1, 400);
      WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
         OWNER         => G_OWNER,
         OBJECT_NAME   => g_object,
         MSG           => G_SQLMSG,
         STATUS        => 'Failed');

      WH_COMMON.PKG_COMMON_UTILITIES.EXIT_AND_REPORT (
         g_jobname,
         'FAILURE',
         $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
      RAISE_APPLICATION_ERROR (-20010, G_SQLMSG);
END;
/
