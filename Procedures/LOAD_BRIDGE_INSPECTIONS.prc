CREATE OR REPLACE PROCEDURE load_bridge_inspections
IS
    /**********************************************************************
    This procedure loadsthe bridge_inspection_history table with data from InspecTech

    It is run daily (complete refresh)

    Modification History:

    08-15-2016 SH Initial Version
    08-30-2016 SH Add correct approval_date, approved_by, inspection dates, inspector, inspection_type
                  to correspond with fixes in extract from InspecTech
    09-06-2016 SH Exclude all inspection types except routine (1) based on meeting on 9/1/16
    09-07-16  SH Remove columns moved to ibridge_history:  FC_INSPECTION_REQUIRED, FC_INSPECTION_FREQUENCY, FC_LAST_INSPECTION
                                                           SI_INSPECTION_REQUIRED, SI_INSPECTION_FREQUENCY, SI_LAST_INSPECTION
                                                           UW_INSPECTION_REQUIRED, UW_INSPECTION_FREQUENCY, UW_LAST_INSPECTION
              since it no longer made sense to have them in the inspection table since it only contains routine inspections
            -  Begin runnng daily as part of ibridges_refresh
            -  Remove last_inspection (last routine inspection) as it is now the same as inspection_date
            -  Add standard error handling
    09-08-16 - SH Modify cursor to select from ext_bridge_inspections external table to match combination of 3 export command files
    10-13-16 - SH Include all inspection types
    10-31-16 - SH Include unapproved inspections
    01-23-17 - SH Add bridge_id to implement history
               NOTE - this needs to be tested more as we get more snapshot years!!!  Verified ok, 7/3/18 with 3 years of bridge data
    06-28-19 - SH When looking up bridge_id to implement history, make sure the STATE is PAST or CURRENT to fix the problem of a bridge
               that had been RETIRED multiple times in one year (ie closed bridge 0067 )
    06-05-24 - SH Remove unapproved inspections - hardcoded to bridge 0067 which has been archived
    06-18-25 - DG DOTDW-1045 Add ASSET_TYPE
    **********************************************************************/

    common_rundate              DATE := SYSDATE;
    cntr                        NUMBER;
    surrogate_key               NUMBER;
    procname                    VARCHAR2 (50) := 'LOAD_BRIDGE_INSPECTIONS';
    num                         NUMBER;

    commit_count                NUMBER := 0;
    counter                     NUMBER := 0;

    field_num                   NUMBER;
    tbridge_id                  NUMBER;
    inspection_yr               NUMBER;

    -- Temporary Variables to lookup descriptions

    dapp_guardrail_end_rating   bridge_inspection_history.app_guardrail_end_rating_descr%TYPE;
    dapp_guardrail_rating       bridge_inspection_history.app_guardrail_rating_descr%TYPE;
    dapp_road_align_rating      bridge_inspection_history.app_road_align_rating_descr%TYPE;
    dchannel_rating             bridge_inspection_history.channel_rating_descr%TYPE;
    dculvert_rating             bridge_inspection_history.culvert_rating_descr%TYPE;
    ddeck_geometry_rating       bridge_inspection_history.deck_geometry_rating_descr%TYPE;
    ddeck_rating                bridge_inspection_history.deck_rating_descr%TYPE;
    dpier_protection_rating     bridge_inspection_history.pier_protection_rating_descr%TYPE;
    drail_rating                bridge_inspection_history.rail_rating_descr%TYPE;
    dscour_rating               bridge_inspection_history.scour_rating_descr%TYPE;
    dstructural_evaluation      bridge_inspection_history.structural_evaluation_descr%TYPE;
    dstructure_open             bridge_inspection_history.structure_open_descr%TYPE;
    dsubstructure_rating        bridge_inspection_history.substructure_rating_descr%TYPE;
    dsuperstructure_rating      bridge_inspection_history.superstructure_rating_descr%TYPE;
    dtransition_rating          bridge_inspection_history.transition_rating_descr%TYPE;
    dunderclearance_rating      bridge_inspection_history.underclearance_rating_descr%TYPE;
    dwater_adequacy_rating      bridge_inspection_history.water_adequacy_rating_descr%TYPE;


    fapp_guardrail_end_rating   NUMBER;
    lapp_guardrail_end_rating   NUMBER;
    fapp_guardrail_rating       NUMBER;
    lapp_guardrail_rating       NUMBER;
    fapp_road_align_rating      NUMBER;
    lapp_road_align_rating      NUMBER;
    fchannel_rating             NUMBER;
    lchannel_rating             NUMBER;
    fculvert_rating             NUMBER;
    lculvert_rating             NUMBER;
    fdeck_geometry_rating       NUMBER;
    ldeck_geometry_rating       NUMBER;
    fdeck_rating                NUMBER;
    ldeck_rating                NUMBER;

    fpier_protection_rating     NUMBER;
    lpier_protection_rating     NUMBER;
    frail_rating                NUMBER;
    lrail_rating                NUMBER;
    fscour_rating               NUMBER;
    lscour_rating               NUMBER;
    fstructural_evaluation      NUMBER;
    lstructural_evaluation      NUMBER;
    fstructure_open             NUMBER;
    lstructure_open             NUMBER;

    fsubstructure_rating        NUMBER;
    lsubstructure_rating        NUMBER;
    fsuperstructure_rating      NUMBER;
    lsuperstructure_rating      NUMBER;

    ftransition_rating          NUMBER;
    ltransition_rating          NUMBER;
    funderclearance_rating      NUMBER;
    lunderclearance_rating      NUMBER;

    fwater_adequacy_rating      NUMBER;
    lwater_adequacy_rating      NUMBER;

    inspections_performed       VARCHAR2 (10);
    inspectionsd_performed      VARCHAR2 (50);

    dup                         BOOLEAN;

    CURSOR brdg
    IS
        SELECT ast_id,
               approval_date,
               approval_status,
               approved_by_fname,
               approved_by_lname,
               app_guardrail_end_rating,
               app_guardrail_rating,
               app_road_alignment_rating,
               asset_type,
               bridge_number,
               channel_rating,
               culvert_rating,
               deck_geometry_rating,
               deck_rating,
               inspection_date,
               inspection_frequency,
               inspection_type,
               inspection_type_descr,
               inspector_last_name,
               inspector_first_name,
               pier_protection_rating,
               rail_rating,
               scour_rating,
               structural_evaluation,
               structure_open,
               substructure_rating,
               superstructure_rating,
               transition_rating,
               underclearance_rating,
               water_adequacy_rating
          FROM ext_approved_inspections
        ORDER BY bridge_number, ast_id, inspection_type;

    r                           brdg%ROWTYPE;
    pr                          brdg%ROWTYPE;



    PROCEDURE Lookup_fe_id_length (column_name    IN     VARCHAR2,
                                   insp_fe_id        OUT NUMBER,
                                   max_desc_len      OUT NUMBER)
    IS
    -- Look up inspecTech field ID and longest length of description
    BEGIN
        SELECT fe_id
          INTO insp_fe_id
          FROM bridge_mappings
         WHERE assets_column = column_name;

        SELECT MAX (LENGTH (description))
          INTO max_desc_len
          FROM bridges_lookup_codes
         WHERE field_id = insp_fe_id;
    END;

    PROCEDURE Lookup_Descriptions
    IS
    BEGIN
        dapp_guardrail_end_rating :=
            bridge_lookup (fapp_guardrail_end_rating,
                           pr.app_guardrail_end_rating,
                           lapp_guardrail_end_rating);

        dapp_guardrail_rating :=
            bridge_lookup (fapp_guardrail_rating,
                           pr.app_guardrail_rating,
                           lapp_guardrail_rating);
        dapp_road_align_rating :=
            bridge_lookup (fapp_road_align_rating,
                           pr.app_road_alignment_rating,
                           lapp_road_align_rating);
        dchannel_rating :=
            bridge_lookup (fchannel_rating,
                           pr.channel_rating,
                           lchannel_rating);
        dculvert_rating :=
            bridge_lookup (fculvert_rating,
                           pr.culvert_rating,
                           lculvert_rating);
        ddeck_geometry_rating :=
            bridge_lookup (fdeck_geometry_rating,
                           pr.deck_geometry_rating,
                           ldeck_geometry_rating);
        ddeck_rating :=
            bridge_lookup (fdeck_rating, pr.deck_rating, ldeck_rating);

        dpier_protection_rating :=
            bridge_lookup (fpier_protection_rating,
                           pr.pier_protection_rating,
                           lpier_protection_rating);
        drail_rating :=
            bridge_lookup (frail_rating, pr.rail_rating, lrail_rating);
        dscour_rating :=
            bridge_lookup (fscour_rating, pr.scour_rating, lscour_rating);
        dstructural_evaluation :=
            bridge_lookup (fstructural_evaluation,
                           pr.structural_evaluation,
                           lstructural_evaluation);
        dstructure_open :=
            bridge_lookup (fstructure_open,
                           pr.structure_open,
                           lstructure_open);
        dsubstructure_rating :=
            bridge_lookup (fsubstructure_rating,
                           pr.substructure_rating,
                           lsubstructure_rating);
        dsuperstructure_rating :=
            bridge_lookup (fsuperstructure_rating,
                           pr.superstructure_rating,
                           lsuperstructure_rating);
        -- transition rating description uses the same description as rail rating description
        dtransition_rating :=
            bridge_lookup (frail_rating, pr.transition_rating, lrail_rating);
        dunderclearance_rating :=
            bridge_lookup (funderclearance_rating,
                           pr.underclearance_rating,
                           lunderclearance_rating);
        dwater_adequacy_rating :=
            bridge_lookup (fwater_adequacy_rating,
                           SUBSTR (pr.water_adequacy_rating, 1, 1),
                           lwater_adequacy_rating);
    END;                                      -- Procedure Lookup Descriptions

    PROCEDURE Write_it
    IS
    BEGIN

        INSERT
          INTO bridge_inspection_history (approval_date,
                                          approval_status,
                                          approval_status_descr,
                                          approved_by,
                                          app_guardrail_end_rating,
                                          app_guardrail_end_rating_descr,
                                          app_guardrail_rating,
                                          app_guardrail_rating_descr,
                                          app_road_align_rating,
                                          app_road_align_rating_descr,
                                          asset_type,
                                          bridge_id,
                                          bridge_number,
                                          channel_rating,
                                          channel_rating_descr,
                                          culvert_rating,
                                          culvert_rating_descr,
                                          deck_geometry_rating,
                                          deck_geometry_rating_descr,
                                          deck_rating,
                                          deck_rating_descr,
                                          inspection_date,
                                          inspection_frequency,
                                          inspection_id,
                                          inspection_type,
                                          inspection_type_descr,
                                          inspector_name,
                                          pier_protection_rating,
                                          pier_protection_rating_descr,
                                          rail_rating,
                                          rail_rating_descr,
                                          scour_rating,
                                          scour_rating_descr,
                                          structural_evaluation,
                                          structural_evaluation_descr,
                                          structure_open,
                                          structure_open_descr,
                                          substructure_rating,
                                          substructure_rating_descr,
                                          superstructure_rating,
                                          superstructure_rating_descr,
                                          transition_rating,
                                          transition_rating_descr,
                                          underclearance_rating,
                                          underclearance_rating_descr,
                                          water_adequacy_rating,
                                          water_adequacy_rating_descr)
            VALUES (
                       convert_to_date (SUBSTR (pr.approval_date, 1, 10),
                                        'yyyy-mm-dd'),
                       pr.approval_status,
                       CASE
                           WHEN pr.approval_status = 5 THEN 'Approved' -- Approval_status_descr
                           ELSE 'Not Approved'
                       END,
                       CASE
                           WHEN pr.approval_status = 5
                           THEN                                 -- Approved_By
                                  pr.approved_by_lname
                               || ', '
                               || pr.approved_by_fname
                           ELSE
                               NULL
                       END,
                       pr.app_guardrail_end_rating,
                       dapp_guardrail_end_rating,
                       pr.app_guardrail_rating,
                       dapp_guardrail_rating,
                       pr.app_road_alignment_rating,
                       dapp_road_align_rating,
                       pr.asset_type,
                       tbridge_id,
                       pr.bridge_number,
                       pr.channel_rating,
                       dchannel_rating,
                       pr.culvert_rating,
                       dculvert_rating,
                       pr.deck_geometry_rating,
                       ddeck_geometry_rating,
                       pr.deck_rating,
                       ddeck_rating,
                       TRUNC (
                           convert_to_date (pr.inspection_date,
                                            'yyyy-mm-dd hh24:mi:ss')),
                       CASE
                           WHEN convert_to_number (pr.inspection_frequency) =
                                    -1
                           THEN
                               NULL
                           ELSE
                               convert_to_number (pr.inspection_frequency)
                       END,
                       Convert_to_number (pr.ast_id),        -- INSPECTION_ID,
                       inspections_performed,
                       inspectionsd_performed,
                          pr.inspector_last_name
                       || ', '
                       || pr.inspector_first_name,
                       pr.pier_protection_rating,
                       dpier_protection_rating,
                       pr.rail_rating,
                       drail_rating,
                       pr.scour_rating,
                       dscour_rating,
                       pr.structural_evaluation,
                       dstructural_evaluation,
                       pr.structure_open,
                       dstructure_open,
                       pr.substructure_rating,
                       dsubstructure_rating,
                       pr.superstructure_rating,
                       dsuperstructure_rating,
                       pr.transition_rating,
                       dtransition_rating,
                       pr.underclearance_rating,
                       dunderclearance_rating,
                       SUBSTR (pr.water_adequacy_rating, 1, 1),
                       dwater_adequacy_rating)
           LOG ERRORS INTO bridge_inspections_error_log
                   ('LOAD BRIDGE INSPECTIONS ' || SYSDATE)
                   REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END;                                                 -- Procedure Write_it
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE bridge_inspections_error_log';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE bridge_inspection_history';

    -- Get fe_id and max length of the description for each _descr column


    Lookup_fe_id_length ('APP_GUARDRAIL_END_RATING',
                         fapp_guardrail_end_rating,
                         lapp_guardrail_end_rating);
    Lookup_fe_id_length ('APP_GUARDRAIL_RATING',
                         fapp_guardrail_rating,
                         lapp_guardrail_rating);
    Lookup_fe_id_length ('APP_ROAD_ALIGNMENT_RATING',
                         fapp_road_align_rating,
                         lapp_road_align_rating);
    Lookup_fe_id_length ('CHANNEL_RATING', fchannel_rating, lchannel_rating);
    Lookup_fe_id_length ('CULVERT_RATING', fculvert_rating, lculvert_rating);
    Lookup_fe_id_length ('DECK_GEOMETRY_RATING',
                         fdeck_geometry_rating,
                         ldeck_geometry_rating);
    Lookup_fe_id_length ('DECK_RATING', fdeck_rating, ldeck_rating);

    Lookup_fe_id_length ('PIER_PROTECTION_RATING',
                         fpier_protection_rating,
                         lpier_protection_rating);
    Lookup_fe_id_length ('RAIL_RATING', frail_rating, lrail_rating);
    Lookup_fe_id_length ('SCOUR_RATING', fscour_rating, lscour_rating);
    Lookup_fe_id_length ('STRUCTURAL_EVALUATION',
                         fstructural_evaluation,
                         lstructural_evaluation);
    Lookup_fe_id_length ('STRUCTURE_OPEN', fstructure_open, lstructure_open);
    Lookup_fe_id_length ('SUBSTRUCTURE_RATING',
                         fsubstructure_rating,
                         lsubstructure_rating);
    Lookup_fe_id_length ('SUPERSTRUCTURE_RATING',
                         fsuperstructure_rating,
                         lsuperstructure_rating);

    Lookup_fe_id_length ('TRANSITION_RATING',
                         ftransition_rating,
                         ltransition_rating);
    Lookup_fe_id_length ('UNDERCLEARANCE_RATING',
                         funderclearance_rating,
                         lunderclearance_rating);



    Lookup_fe_id_length ('WATERWAY_ADEQUACY_RATING',
                         fwater_adequacy_rating,
                         lwater_adequacy_rating);

    OPEN brdg;

    -- Process first Record
    FETCH brdg INTO r;

    inspections_performed := TRIM (TRAILING ' ' FROM r.inspection_type);
    inspectionsd_performed :=
        TRIM (TRAILING ' ' FROM r.inspection_type_descr);
    pr := r;
    Lookup_descriptions;

    LOOP
        FETCH brdg INTO r;

        EXIT WHEN brdg%NOTFOUND;

        IF r.ast_id = pr.ast_id                      -- same inspection number
        THEN
            IF r.inspection_type <> pr.inspection_type                 -- dup?
            THEN
                inspections_performed :=
                       TRIM (TRAILING ' ' FROM inspections_performed)
                    || ','
                    || TRIM (TRAILING ' ' FROM r.inspection_type);
                inspectionsd_performed :=
                       TRIM (TRAILING ' ' FROM inspectionsd_performed)
                    || ','
                    || TRIM (TRAILING ' ' FROM r.inspection_type_descr);
                pr := r;
            END IF;
        ELSE                                          -- New inspection number
            BEGIN

                Lookup_descriptions;
                -- Lookup bridge_id for year of inspection
                inspection_yr :=
                    EXTRACT (
                        YEAR FROM convert_to_date (pr.inspection_date,
                                                   'yyyy-mm-dd hh24:mi:ss'));

                SELECT COUNT (*)
                  INTO cntr
                  FROM ibridges_history b
                 WHERE     pr.bridge_number = b.bridge_number
                       AND b.snapshot_year = inspection_yr
                       AND b.state IN ('CURRENT', 'PAST');
                       

                IF cntr = 1
                THEN
                    SELECT bridge_id
                      INTO tbridge_id
                      FROM ibridges_history b
                     WHERE     pr.bridge_number = b.bridge_number
                           AND b.snapshot_year = inspection_yr
                           AND b.state IN ('CURRENT', 'PAST');
                ELSE  
                        tbridge_id := NULL;
                    
                END IF;


                write_it;
                pr := r;
                inspections_performed :=
                    TRIM (TRAILING ' ' FROM r.inspection_type);
                inspectionsd_performed :=
                    TRIM (TRAILING ' ' FROM r.inspection_type_descr);
            END;
        END IF;
    END LOOP;

    -- Lookup bridge_id for year of inspection last row
    inspection_yr :=
        EXTRACT (
            YEAR FROM convert_to_date (pr.inspection_date,
                                       'yyyy-mm-dd hh24:mi:ss'));

    SELECT COUNT (*)
      INTO cntr
      FROM ibridges_history b
     WHERE     pr.bridge_number = b.bridge_number
           AND b.snapshot_year = inspection_yr
           AND b.state IN ('CURRENT', 'PAST');

    IF cntr = 1
    THEN
        SELECT bridge_id
          INTO tbridge_id
          FROM ibridges_history b
         WHERE     pr.bridge_number = b.bridge_number
               AND b.snapshot_year = inspection_yr
               AND b.state IN ('CURRENT', 'PAST');
    ELSE
            tbridge_id := NULL;
    
    END IF;

    Write_it;                                                      -- last row
    COMMIT;


    SELECT COUNT (*) INTO cntr FROM bridge_inspection_history;



    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
        OWNER         => 'WH_ASSETS',
        OBJECT_NAME   => 'BRIDGE_INSPECTION_HISTORY',
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
