CREATE OR REPLACE PROCEDURE load_element_inspections
IS
    /**********************************************************************
    This procedure is the initial load of the element_inspection_history table with data from InspecTech

    It reads the data from EXT_BRIDGE_ELEMENT_INSPECTIONS external table
    It combines data from the same inspection (AST_ID) and element into one row

    It is run once for the initial load.  To start with we will rerun this daily (complete refresh)

    Modification History:

    09-09-2016 SH Initial Version
    09-29-2016 SH Add element parents
    11-07-2016 SH Store 0 instead of -1 when qty is null
    03-20-17 SH Sum the condition states and totals, check that the environment is also the same to fix a bug
                where the totals are not adding up correctly
    11-04-19 SH Initialize ttot_qty
    08-28-23 SH Remove last character from parent asset when it is a carriage return (ascii 13)
    **********************************************************************/

    common_rundate               DATE := SYSDATE;
    cntr                         NUMBER;
    commit_count                 NUMBER := 0;

    tbridge_id                   NUMBER;
    tbridge_name                 element_inspection_history.bridge_name%TYPE;
    tbridge_number               element_inspection_history.bridge_number%TYPE;
    telement_number              element_inspection_history.element_number%TYPE;
    telement_name                element_inspection_history.element_name%TYPE;
    telement_parent_number       element_inspection_history.element_parent_number%TYPE;
    telement_parent_name         element_inspection_history.element_parent_name%TYPE;
    tuom                         element_inspection_history.uom%TYPE;
    tenvironment                 element_inspection_history.environment%TYPE;
    tinspection_date             element_inspection_history.inspection_date%TYPE;
    tinspection_id               element_inspection_history.inspection_id%TYPE;
    ttot_qty                     element_inspection_history.tot_qty%TYPE := 0;
    tcondition_state1            NUMBER := 0;
    tcondition_state2            NUMBER := 0;
    tcondition_state3            NUMBER := 0;
    tcondition_state4            NUMBER := 0;


    CURSOR brdg IS
          SELECT a.ast_id,
                 a.bridge_number,
                 b.bridge_name,
                 b.bridge_id,
                 element_name,
                 element_number,
                 environment,
                 field_id,
                 field_name,
                 a.inspection_date,
                 qty,
                 uom,
                 element_parent_number,
                 element_parent_name
            FROM ext_bridge_element_inspections a
                 JOIN ibridges_history b ON a.bridge_number = b.bridge_number
           WHERE b.end_date IS NULL
        ORDER BY a.bridge_number,
                 a.ast_id,
                 a.element_number,
                 a.element_parent_number,
                 a.environment;

    rec                          brdg%ROWTYPE;


    prev_ast_id                  ext_bridge_element_inspections.ast_id%TYPE;
    prev_element_number          ext_bridge_element_inspections.element_number%TYPE;
    prev_element_parent_number   ext_bridge_element_inspections.element_parent_number%TYPE;
    prev_environment             ext_bridge_element_inspections.environment%TYPE;


    PROCEDURE Setup_first_element
    IS
    -- Sets up first element in an inspection
    BEGIN
        prev_ast_id := rec.ast_id;
        prev_element_number := rec.element_number;
        prev_element_parent_number := rec.element_parent_number;
        prev_environment := rec.environment;
        tbridge_id := rec.bridge_id;
        tbridge_name := rec.bridge_name;
        tbridge_number := rec.bridge_number;
        telement_number := Convert_to_number (rec.element_number);
        telement_name := rec.element_name;
        telement_parent_number :=
            Convert_to_number (rec.element_parent_number);
        telement_parent_name := rec.element_parent_name;
        tuom := rec.uom;
        tenvironment := rec.environment;
        tinspection_date :=
            TRUNC (
                convert_TO_DATE (rec.inspection_date,
                                 'yyyy-mm-dd hh24:mi:ss'));
        tinspection_id := rec.ast_id;
    END;                                     -- Procedure Set_up_first_element

    PROCEDURE Setup_condition_states (amt IN VARCHAR)
    IS
        num   NUMBER;
    BEGIN
        num := Convert_to_number (amt);

        IF num = -1
        THEN
            num := 0;
        END IF;

        IF rec.field_id = '5000013'
        THEN
            ttot_qty := ttot_qty + num;
        ELSE
            IF rec.field_id = '5000014'
            THEN
                tcondition_state1 := tcondition_state1 + num;
            ELSE
                IF rec.field_id = '5000015'
                THEN
                    tcondition_state2 := tcondition_state2 + num;
                ELSE
                    IF rec.field_id = '5000016'
                    THEN
                        tcondition_state3 := tcondition_state3 + num;
                    ELSE
                        IF rec.field_id = '5000017'
                        THEN
                            tcondition_state4 := tcondition_state4 + num;
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
    END;                                  -- Procedure Set_up_condition_states


    PROCEDURE Write_it
    IS
    BEGIN
        INSERT INTO element_inspection_history (bridge_id,
                                                bridge_name,
                                                bridge_number,
                                                element_number,
                                                element_name,
                                                element_parent_number,
                                                element_parent_name,
                                                uom,
                                                environment,
                                                inspection_date,
                                                inspection_id,
                                                tot_qty,
                                                condition_state1,
                                                condition_state2,
                                                condition_state3,
                                                condition_state4)
                 VALUES (
                            tbridge_id,
                            tbridge_name,
                            tbridge_number,
                            telement_number,
                            telement_name,
                            telement_parent_number,
                            CASE
                                WHEN ASCII (
                                         SUBSTR (telement_parent_name, -1)) =
                                     13 -- is the last character a carriage return
                                THEN
                                    SUBSTR (
                                        telement_parent_name,
                                        1,
                                        LENGTH (telement_parent_name) - 1) 
                                ELSE
                                    telement_parent_name
                            END,
                            tuom,
                            tenvironment,
                            tinspection_date,
                            tinspection_id,
                            ttot_qty,
                            tcondition_state1,
                            tcondition_state2,
                            tcondition_state3,
                            tcondition_state4)
                LOG ERRORS INTO element_inspection_ERROR_LOG
                        ('LOAD ELEMENT INSPECTIONS ' || SYSDATE)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;

        tcondition_state1 := 0;
        tcondition_state2 := 0;
        tcondition_state3 := 0;
        tcondition_state4 := 0;
        ttot_qty := 0;
    END;                                                 -- Procedure Write_It
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE element_inspection_error_log';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE element_inspection_history';


    OPEN brdg;

    -- Process first rord
    FETCH brdg INTO rec;

    Setup_first_element;
    Setup_condition_states (rec.qty);



    LOOP
        FETCH brdg INTO rec;

        EXIT WHEN brdg%NOTFOUND;

        IF rec.ast_id = prev_ast_id                  -- same inspection number
        THEN
            IF    (    rec.element_number = prev_element_number
                   AND rec.element_parent_number IS NULL
                   AND prev_element_parent_number IS NULL
                   AND rec.environment = prev_environment)
               OR (    rec.element_number = prev_element_number
                   AND rec.element_parent_number = prev_element_parent_number
                   AND rec.environment = prev_environment)
            THEN
                Setup_condition_states (rec.qty);
            ELSE                                                -- New element
                BEGIN
                    Write_it;
                    -- save new stuff about the element
                    telement_number := Convert_to_number (rec.element_number);
                    telement_name := rec.element_name;
                    telement_parent_number :=
                        Convert_to_number (rec.element_parent_number);
                    telement_parent_name := rec.element_parent_name;
                    tuom := rec.uom;
                    tenvironment := Convert_to_number (rec.environment);
                    prev_element_number := rec.element_number;
                    prev_element_parent_number := rec.element_parent_number;
                    prev_environment := rec.environment;
                    Setup_condition_states (rec.qty);
                END;
            END IF;
        ELSE                                                 -- New Inspection
            Write_it;
            -- save new stuff about the inspection
            Setup_first_element;
            Setup_condition_states (rec.qty);
        END IF;
    END LOOP;

    Write_it;                                                      -- last row
    COMMIT;



    SELECT COUNT (*) INTO cntr FROM element_inspection_history;


    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
        OWNER         => 'WH_ASSETS',
        OBJECT_NAME   => 'ELEMENT_INSPECTION_HISTORY',
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
