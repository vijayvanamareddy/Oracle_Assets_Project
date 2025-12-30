CREATE OR REPLACE PROCEDURE load_ibridge_inspection_date
IS
/**********************************************************************
This procedure loads the most recent 'approved' inspection type and date into the ibridges_history table.
It is run after loading the inspection data from InspecTech

9/6/2016  SH   Initial Version
9/14/2016 SH  Update staging table not history table
10/31/16  SH  Add qualifier to select approved inspections since unapproved inspections have been added to the bridge_inspection_history table
11/9/2016 SH Add standard error handling
04/04/17 SH  Fix case when 2 different types of inspections are the same date with different inspection numbers - include them both in the latest inspection
04/10/17 SH  Add sort by inspection_type to cursor so order of inspections won't change when there are 2 different types of inspections on the same date
04/11/17  SH  Add last_element_inspection_date, last_routine_inspection_date
04/24/17 SH  Add the most recent field_review_date and field_review_status
04/27/17 SH Log procedure & function when other exceptions in data exceptions table
5/15/17  SH  Add the most recent inspection of anytype, column: last_inspection_anytype  
             The column inspection_date is NBI 90 (last routine inspection); the source being currentvalues in InspectTech (change today)
             The column last_routine_inspection is derived from looking at the actual inspections (no change from 4/11/17)
6/6/17   SH  Update ibridges_history current row rather than the staging table.  Executing this procedure after the refresh of ibridges_history is complete 
4/3/18   SH  Modify function Get_Last_Field_Review to handle the case of multiple rows for rail bridges that are also highway bridges in inspectTech     
2/14/19 SH  Increase the size of the variable  inspectionsd_performed which is the descriptions of the inspections to fix case where there are multiple
            inspection types and ast_ids on the same date, some approved and others not approved 
06-18-25 - DG DOTDW-1045 Update LAST_ROUTINE_INSPECTION_DATE with matching ASSET_TYPE. Exclude SNBI inspection types.   
07-08-25 - DG cont If inspection asset type Highway exists for bridge then select it else disregard asset type.        
*******************************************************************************************************************************************************/

BEGIN
    DECLARE
        CURSOR brdg               -- get the latest inspection for each bridge
        IS
              SELECT i.bridge_number,
                     i.inspection_type,
                     i.inspection_type_descr,
                     i.inspection_date
                FROM bridge_inspection_history i
               WHERE (i.bridge_number, i.inspection_date) IN
                         (  SELECT bridge_number, MAX (inspection_date)
                              FROM bridge_inspection_history m
                             WHERE approval_status = 5
                               AND (
                                   NOT EXISTS (
                                       SELECT bridge_number
                                         FROM bridge_inspection_history m2
                                        WHERE approval_status = 5
                                          AND m2.bridge_number = m.bridge_number
                                          AND asset_type = 'Highway Bridge'
                                    )
                                    OR
                                    asset_type = 'Highway Bridge'
                              )        
                          GROUP BY bridge_number)
            ORDER BY bridge_number, i.inspection_type;

        r                         brdg%ROWTYPE;
        pr                        brdg%ROWTYPE;

        inspections_performed     VARCHAR2 (10);
        inspectionsd_performed    VARCHAR2 (130);
        last_routine_inspection   DATE;
        last_element_inspection   DATE;
        last_field_review         DATE;
        last_field_review_status  BRIDGE_WORKPLAN_FIELD_REVIEW.field_review_status%TYPE;

        commit_count              NUMBER := 0;
        cntr                      NUMBER := 0;
        start_time                DATE := SYSDATE;

        FUNCTION Get_Last_Routine_Inspection (bridge_no IN VARCHAR2)
            RETURN DATE
        IS
            insp_date   DATE;
            err         VARCHAR2(100);
        BEGIN
            SELECT MAX (m.inspection_date)
              INTO insp_date
              FROM bridge_inspection_history m
             WHERE     m.approval_status = 5
                   AND (m.inspection_type = '1' or m.inspection_type like '1,%')
                   AND m.bridge_number = bridge_no
                   AND (
                       NOT EXISTS (
                           SELECT m.bridge_number
                            FROM bridge_inspection_history m
                           WHERE m.approval_status = 5
                             AND (m.inspection_type = '1' or m.inspection_type like '1,%')
                             AND m.bridge_number = bridge_no
                             AND m.asset_type = 'Highway Bridge'
                       )
                       OR
                       m.asset_type = 'Highway Bridge'
                    );        
                           
            RETURN insp_date;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN NULL;
            WHEN OTHERS
            THEN
             err := 'Error num :'||to_char(sqlcode)||' '||substr(sqlerrm,1,70);
             INSERT INTO data_exceptions (TABLE_NAME,                                
                                      ERROR_CONDITION,                                     
                                      TEST_PROCEDURE,
                                      TEST_DATE,
                                      ASSESSMENT,
                                     COLUMN_NAME1,
                                     COLUMN_VALUE1,
                                     COLUMN_NAME2,
                                     COLUMN_VALUE2)
                      VALUES ('ibridges_history',
                              err,
                              $$PLSQL_UNIT,
                              start_time,
                              'EXCEPTION',
                              'FUNCTION',
                              'Get_Last_Routine_Inspection',
                              'BRIDGE_NUMBER',
                              bridge_no);  
         RETURN NULL;
            
           
        END;

        FUNCTION Get_Last_Element_Inspection (bridge_no IN VARCHAR2)
            RETURN DATE
        IS
            ele_insp_date   DATE;
            err       VARCHAR2(100);
        BEGIN
            SELECT MAX (inspection_date)
              INTO ele_insp_date
              FROM element_inspection_history e
             WHERE e.bridge_number = bridge_no;

            RETURN ele_insp_date;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN NULL;
            WHEN OTHERS THEN
            err := 'Error num :'||to_char(sqlcode)||' '||substr(sqlerrm,1,70);
             INSERT INTO data_exceptions (TABLE_NAME,                                
                                      ERROR_CONDITION,                                     
                                      TEST_PROCEDURE,
                                      TEST_DATE,
                                      ASSESSMENT,
                                     COLUMN_NAME1,
                                     COLUMN_VALUE1,
                                     COLUMN_NAME2,
                                     COLUMN_VALUE2)
                      VALUES ('ibridges_history',
                              err,
                              $$PLSQL_UNIT,
                              start_time,
                              'EXCEPTION',
                              'FUNCTION',
                              'Get_Last_Element_Inspection',
                              'BRIDGE_NUMBER',
                              bridge_no);  
                RETURN NULL;
          
        END;
        
        PROCEDURE Get_Last_Field_Review (bridge_no IN VARCHAR2,
                                         last_field_rev OUT DATE,
                                         last_field_rev_stat OUT VARCHAR2)
            
        IS
             err       VARCHAR2(100);
        BEGIN
            SELECT field_review_status, MAX (field_review_date)
              INTO last_field_rev_stat, last_field_rev
              FROM BRIDGE_WORKPLAN_FIELD_REVIEW r            
             WHERE     
                    r.bridge_number = bridge_no and r.field_review_date is not null
                    GROUP BY r.field_review_status;

           
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                last_field_rev := NULL;
                last_field_rev_stat := NULL;
            WHEN OTHERS THEN
            err := 'Error num :'||to_char(sqlcode)||' '||substr(sqlerrm,1,70);
             INSERT INTO data_exceptions (TABLE_NAME,                                
                                      ERROR_CONDITION,                                     
                                      TEST_PROCEDURE,
                                      TEST_DATE,
                                      ASSESSMENT,
                                     COLUMN_NAME1,
                                     COLUMN_VALUE1,
                                     COLUMN_NAME2,
                                     COLUMN_VALUE2)
                      VALUES ('ibridges_history',
                              err,
                              $$PLSQL_UNIT,
                              start_time,
                              'EXCEPTION',
                              'FUNCTION',
                              'Get_Last_Field_Review',
                              'BRIDGE_NUMBER',
                              bridge_no);              
                last_field_rev := NULL;
                last_field_rev_stat := NULL;
        END;

        
    BEGIN
        OPEN brdg;

        -- Process first Record
        FETCH brdg INTO r;

        inspections_performed := r.inspection_type;
        inspectionsd_performed := r.inspection_type_descr;

        IF (r.inspection_type = '1' or r.inspection_type like '1,%')
        THEN
            last_routine_inspection := r.inspection_date;
        ELSE
            last_routine_inspection :=
                Get_Last_Routine_Inspection (r.bridge_number);
        END IF;

        last_element_inspection :=
            Get_Last_Element_Inspection (r.bridge_number);
        pr := r;


        LOOP
            FETCH brdg INTO r;

            EXIT WHEN brdg%NOTFOUND;

            IF r.bridge_number = pr.bridge_number       -- same bridge number?
            THEN
                IF r.inspection_type <> pr.inspection_type -- different type of inspection on same day
                THEN
                    inspections_performed :=
                           TRIM (TRAILING ' ' FROM inspections_performed)
                        || ','
                        || TRIM (TRAILING ' ' FROM r.inspection_type);
                    inspectionsd_performed :=
                           TRIM (TRAILING ' ' FROM inspectionsd_performed)
                        || ','
                        || TRIM (TRAILING ' ' FROM r.inspection_type_descr);

                    IF (r.inspection_type = '1' or r.inspection_type like '1,%')
                    THEN
                        last_routine_inspection := r.inspection_date;
                    ELSE
                        last_routine_inspection :=
                            Get_Last_Routine_Inspection (r.bridge_number);
                    END IF;

                    last_element_inspection :=
                        Get_Last_Element_Inspection (r.bridge_number);
                        Get_Last_Field_Review (r.bridge_number, last_field_review, last_field_review_status);
                    pr := r;                                       -- save rec
                END IF;
            ELSE                                          -- New bridge number
                BEGIN
                    UPDATE ibridges_history b       -- update the prior bridge
                       SET inspection_type = inspections_performed,
                           inspection_type_descr = inspectionsd_performed,
                           last_inspection_anytype   = pr.inspection_date,  
                           last_routine_inspection_date =
                               last_routine_inspection,
                           last_element_inspection_date =
                               last_element_inspection,
                               field_review_date = last_field_review,
                           field_review_status = last_field_review_status
                     WHERE b.bridge_number = pr.bridge_number AND end_date is NULL
                       LOG ERRORS INTO ibridges_history_error_log
                               (   'Procedure: Load_Bridge_Inspection_date failed'
                                || SYSDATE)
                               REJECT LIMIT 100;

                    commit_count := commit_count + 1;

                    IF commit_count > 1000
                    THEN
                        COMMIT;
                        commit_count := 0;
                    END IF;

                    inspections_performed := r.inspection_type;
                    inspectionsd_performed := r.inspection_type_descr;

                    IF (r.inspection_type = '1' or r.inspection_type like '1,%')
                    THEN
                        last_routine_inspection := r.inspection_date;
                    ELSE
                        last_routine_inspection :=
                            Get_Last_Routine_Inspection (r.bridge_number);
                    END IF;

                    last_element_inspection :=
                        Get_Last_Element_Inspection (r.bridge_number);
                        Get_Last_Field_Review (r.bridge_number, last_field_review, last_field_review_status);
                    pr := r;
                END;
            END IF;
        END LOOP;

        UPDATE ibridges_history b                    -- update the last bridge
           SET inspection_type = inspections_performed,
               inspection_type_descr = inspectionsd_performed,
               last_inspection_anytype   = pr.inspection_date,  
               last_routine_inspection_date = last_routine_inspection,
               last_element_inspection_date = last_element_inspection,
               field_review_date = last_field_review,
               field_review_status = last_field_review_status
         WHERE b.bridge_number = pr.bridge_number AND end_date is NULL
           LOG ERRORS INTO ibridges_history_error_log
                   (   'Procedure: Load_Bridge_Inspection_date failed'
                    || SYSDATE)
                   REJECT LIMIT 100;

        COMMIT;

        SELECT COUNT (*) INTO cntr FROM ibridges_history;

        WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
            OWNER         => 'WH_ASSETS',
            OBJECT_NAME   => 'IBRIDGES_HISTORY',
            object_cnt    => cntr,
            proc          => $$PLSQL_UNIT,
            start_time    => start_time);

        COMMIT;
    END;
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
               'Error during '
            || $$PLSQL_UNIT
            || ': '
            || SUBSTR (SQLERRM, 1, 400));
        RAISE_APPLICATION_ERROR (
            -20050,
            $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
END;
/
