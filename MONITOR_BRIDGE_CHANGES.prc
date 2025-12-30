CREATE OR REPLACE PROCEDURE monitor_bridge_changes
IS
    /**********************************************************************
      This procedure checks the ibridges_changes change log to generate a report when
      the following changes are made in InspectTech.

       a. New Bridge is Added,
       b. Bridge is Archived, (asset_status set to 0)
       c. Change in (x,y) location (latitude or longitude)

       It reports on the latest changes and uses ALERT12 and ALERT14

      Written for Devon Witherell, GIS Coordinator

      05-10-2018  SH  Initial Version
      04-20-2023  SH  Modify cursor for archived_bridge - shows as a deleted row in ibridges_changes
                      Add check for archived without a reason, uses ALERT14  (DOTDW-786)
      ********************************/
    err_msg   VARCHAR2 (400);
    cntr      NUMBER (7) := 0;
    descr     VARCHAR2 (100) := NULL;

    CURSOR new_bridge IS
        SELECT bridge_number, change_date
          FROM IBRIDGES_CHANGES
         WHERE     TO_CHAR (change_date, 'MM/DD/YYYY') IN
                       (SELECT TO_CHAR (MAX (change_date), 'MM/DD/YYYY')
                          FROM ibridges_changes)
               AND CHANGE_TYPE = 'I'
               AND (   MODIFIED_BY = 'IBRIDGES_REFRESH'
                    OR MODIFIED_BY = 'IBRIDGES_WEEKEND_REFRESH');

    --   cursor archived_bridge is
    --   SELECT BRIDGE_NUMBER, change_date FROM IBRIDGES_CHANGES WHERE to_char(change_date, 'MM/DD/YYYY') IN (select to_char(max(change_date), 'MM/DD/YYYY') from ibridges_changes)
    --   AND COLUMN_NAME = 'ASSET_STATUS' AND NEW_VALUE = 0;

    CURSOR archived_bridge IS
        SELECT e.BRIDGE_NUMBER, c.change_date, e.archived_reason
          FROM IBRIDGES_CHANGES  c
               JOIN ext_archived_bridges e
                   ON c.bridge_number = e.bridge_number
         WHERE     TO_CHAR (change_date, 'MM/DD/YYYY') IN
                       (SELECT TO_CHAR (MAX (change_date), 'MM/DD/YYYY')
                          FROM ibridges_changes)
               AND change_type = 'D';

    CURSOR loc IS
        SELECT BRIDGE_NUMBER,
               CHANGE_DATE,
               COLUMN_NAME,
               OLD_VALUE,
               NEW_VALUE
          FROM IBRIDGES_CHANGES
         WHERE     (COLUMN_NAME = 'LATITUDE' OR COLUMN_NAME = 'LONGITUDE')
               AND TO_CHAR (change_date, 'MM/DD/YYYY') IN
                       (SELECT TO_CHAR (MAX (change_date), 'MM/DD/YYYY')
                          FROM ibridges_changes);
BEGIN
    FOR rec IN new_bridge
    LOOP
        WH_COMMON.POST_TO_ALERT_LOG (
            'ALERT12',
            'WH_ASSETS',
            $$PLSQL_UNIT,
               'New Bridge Number: '
            || rec.bridge_number
            || ' was Inserted into the Data Warehouse on: '
            || rec.change_date);
    END LOOP;

    COMMIT;


    FOR a IN archived_bridge
    LOOP
        WH_COMMON.POST_TO_ALERT_LOG (
            'ALERT12',
            'WH_ASSETS',
            $$PLSQL_UNIT,
               'Bridge Number: '
            || a.bridge_number
            || ' was Archived (asset_status = 0) in the Data Warehouse on: '
            || a.change_date
            || ' because : '
            || a.archived_reason);

        IF a.archived_reason IS NULL
        THEN
            WH_COMMON.POST_TO_ALERT_LOG (
                'ALERT14',
                'WH_ASSETS',
                $$PLSQL_UNIT,
                   'Bridge Number: '
                || a.bridge_number
                || ' was Archived (asset_status = 0) in the Data Warehouse on: '
                || a.change_date
                || ' MISSING AN ARCHIVED REASON');
        END IF;
    END LOOP;

    COMMIT;

    FOR l IN loc
    LOOP
        WH_COMMON.POST_TO_ALERT_LOG (
            'ALERT12',
            'WH_ASSETS',
            $$PLSQL_UNIT,
               'Bridge Number: '
            || l.bridge_number
            || ' '
            || l.column_name
            || ' Changed from '
            || l.old_value
            || ' to '
            || l.new_value
            || ' in the Data Warehouse on: '
            || l.change_date);
    END LOOP;

    COMMIT;
EXCEPTION
    WHEN OTHERS
    THEN
        err_msg := SUBSTR (SQLERRM, 1, 350);

        INSERT INTO WH_COMMON.tberrlog (err_datetime,
                                        err_oid,
                                        err_module,
                                        err_message)
             VALUES (SYSDATE,
                     USER,
                     'monitor_routine_bridge_changes',
                     'Unexpected failure: ' || err_msg);

        COMMIT;
        wh_fact.pkg_email.p_email_message (
            recipient   => 'susan.hillson@maine.gov',
            subject     => 'monitor_bridge_changes Has Failed',
            bodyText    =>
                   'An unexpected failure has occurred: '
                || err_msg
                || CHR (10)
                || CHR (13)
                || CHR (10)
                || CHR (13)
                || ' '
                || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS'));
END;
/
