CREATE OR REPLACE PROCEDURE load_workplan_review
IS
    /**********************************************************************
    This procedure loads the bridge_workplan_review table with data from InspecTech

    It reads the data from the EXT_WORKPLAN_REV external tables

    It does a complete refresh daily 

    Modification History:

    04-10-2017 SH Initial Version
    06-13-2017 SH Change Inspecttech source for comments
    07-11-2017 SH Fix problem where some of the long comments were not extracted from InspectTech
    03-27-2018 SH Remove next_review_date column
                  Remove 2nd workplan review table
                  to support Change of source columns in InspectTech to combine the two Bridge Management forms into one.
                  The Work Plan Field Review form is being eliminated and the data transferred to new fields on the
                  Bridge Management Info (Dan Lapointe request)
    04-02-2018 SH If reason is null make it blank (Cindy Owings request)     
    05-17-2018 SH Try to get rid of the bad file by adding bridge name after comments  
    05-22-2018 SH Remove check for nulls since we no longer are using the repeating columns in inspecttech  
    09-21-2018 SH Remove duplicate bridges that have no data - duplicates are stored in inspecttech for some of the rail bridges   
                  The data in the cursor is ordered so duplicates sort last  
    11-25-2018 SH Change references of ibridges to ibridges_history WHERE end_date is NULL to facilitate change to new bridge selection criteria    
    02-03-2023 SH Replace non-printing characters in comments with ' ' - DOTDW-764        
    **********************************************************************/

    common_rundate   DATE := SYSDATE;
    cntr             NUMBER;
    commit_count     NUMBER := 0;



    CURSOR brdg
    IS
          SELECT p.bridge_number,
                 b.bridge_id,
                 REGEXP_REPLACE(p.comments, '[^ -~|[:space:]]', ' ') as comments,
                 p.field_review_date,
                 p.field_review_status,
                 p.reason
            FROM ext_workplan_rev p
                 JOIN ibridges_history b ON p.bridge_number = b.bridge_number
                 WHERE b.end_date IS NULL
                 order by  p.bridge_number, 
                           p.field_review_date,-- rows without data sort last;
                           p.field_review_status desc,
                           p.reason desc,
                           p.comments desc;  

        rec brdg%ROWTYPE;
        
        prev_bridge_number ibridges_history.bridge_number%TYPE;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE workplan_fieldrev_error_log';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE bridge_workplan_field_review';
    
    OPEN brdg;  
    FETCH brdg INTO rec; 
    prev_bridge_number := rec.bridge_number; 
    INSERT INTO bridge_workplan_field_review (bridge_id,bridge_number, field_review_status, reason,field_review_date, COMMENTS)
             VALUES (rec.bridge_id,rec.bridge_number, rec.field_review_status, rec.reason,   Convert_to_date (rec.field_review_date, 'MM/DD/YYYY'), REPLACE ( (rec.comments), ';', ','))
              LOG ERRORS INTO workplan_fieldrev_error_log
                        ('LOAD WORKPLAN FIELD REVIEW ' || SYSDATE)
                        REJECT LIMIT 100;
    commit_count := commit_count + 1;
    
    LOOP
    
      FETCH brdg INTO rec; 
      EXIT WHEN brdg%NOTFOUND;
      
      IF rec.bridge_number <> prev_bridge_number -- new brIdge?
         THEN  
            prev_bridge_number := rec.bridge_number; 
            INSERT INTO bridge_workplan_field_review (bridge_id,bridge_number, field_review_status, reason,field_review_date, COMMENTS)
             VALUES (rec.bridge_id,rec.bridge_number, rec.field_review_status, rec.reason,   Convert_to_date (rec.field_review_date, 'MM/DD/YYYY'), REPLACE ( (rec.comments), ';', ','))
              LOG ERRORS INTO workplan_fieldrev_error_log
                        ('LOAD WORKPLAN FIELD REVIEW ' || SYSDATE)
                        REJECT LIMIT 100;
            commit_count := commit_count + 1;
            IF commit_count > 1000
            THEN
                COMMIT;
                commit_count := 0;
            END IF;
     END IF;   
         
    END LOOP;
    
    CLOSE brdg;
    COMMIT;

   SELECT COUNT (*) INTO cntr FROM bridge_workplan_field_review;

    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
        OWNER         => 'WH_ASSETS',
        OBJECT_NAME   => 'bridge_workplan_field_review',
        object_cnt    => cntr,
        add_cnt       => cntr,
        proc          => $$PLSQL_UNIT,
        start_time    => common_rundate);
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
        RAISE_APPLICATION_ERROR (-20052, SUBSTR (SQLERRM, 1, 400));
END;
/
