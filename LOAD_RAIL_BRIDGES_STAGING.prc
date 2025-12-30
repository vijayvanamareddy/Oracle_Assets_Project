CREATE OR REPLACE PROCEDURE load_rail_bridges_staging
IS
    /**********************************************************************
    This procedure loads the rail_bridges_staging table which contains the
    attributes unique to rail bridges.

    06-12-2017 S. Hillson - Initial Version
    
    10-11-2022 SH - Add column RR_ACTIVE_LINE Jira task DOTDW-714
    10-17-2022 SH - Add columns YRREPAIR1_HOW, YRREPAIR1_SCOPE
    **********************************************************************/

    commit_count         NUMBER (7) := 0;
    cntr                 NUMBER (7) := 0;
   
    g_start_time         DATE := SYSDATE;
    g_owner              VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname            VARCHAR2 (30) := 'LOAD_RAIL_BRIDGES_STAGING';
    g_object             VARCHAR2 (20) := 'RAIL_BRIDGES_STAGING';
    g_sqlmsg             VARCHAR2 (500) := NULL;

    CURSOR brdg
    IS
        SELECT 
               r.bridge_number,
               rr_active_line,
               rr_deck_type,
               rr_lr_limiting_speed,
               rr_lr_rating_factor_4axle,
               rr_lr_rating_factor_e80,
               rr_lr_rating_factor_veh3,
               rr_lr_rating_factor_veh4,
               rr_lr_speed_4axle,
               rr_lr_speed_e80,
               rr_lr_speed_veh3,
               rr_lr_speed_veh4,
               rr_lr_vehicle3,
               rr_lr_vehicle4,
               rr_lr_vehweight_4axle,
               rr_lr_vehweight_e80,
               rr_lr_weight_4axle,
               rr_lr_weight_e80,
               rr_lr_weight_veh3,
               rr_lr_weight_veh4,
               rr_operator,
               rr_route_number,
               rr_track_alignment,
               rr_track_class,
               rr_track_speed_freight,
               rr_track_speed_passenger,
               rr_track_surface,
               rr_track_type,
               structure_type_description,
               yrrepair1_how,
               yrrepair1_notes,
               yrrepair2_notes,
               yrrepair3_notes,
               yrrepair4_notes,
               yrrepair5_notes,
               yrrepair1_scope
          FROM ext_rail_bridges_unique_cols  r;
               
BEGIN

 EXECUTE IMMEDIATE 'truncate table rail_bridges_staging';
 
 

    FOR b IN brdg
    LOOP
         
        INSERT INTO rail_bridges_STAGING (
                                          bridge_number,
                                          rr_active_line,
                                          rr_deck_type,
                                          rr_lr_limiting_speed,
                                          rr_lr_rating_factor_4axle,
                                          rr_lr_rating_factor_e80,
                                          rr_lr_rating_factor_veh3,
                                          rr_lr_rating_factor_veh4,
                                          rr_lr_speed_4axle,
                                          rr_lr_speed_e80,
                                          rr_lr_speed_veh3,
                                          rr_lr_speed_veh4,
                                          rr_lr_vehicle3,
                                          rr_lr_vehicle4,
                                          rr_lr_vehweight_4axle,
                                          rr_lr_vehweight_e80,
                                          rr_lr_weight_4axle,
                                          rr_lr_weight_e80,
                                          rr_lr_weight_veh3,
                                          rr_lr_weight_veh4,
                                          rr_operator,
                                          rr_route_number,
                                          rr_track_alignment,
                                          rr_track_class,
                                          rr_track_speed_freight,
                                          rr_track_speed_passenger,
                                          rr_track_surface,
                                          rr_track_type,
                                          structure_type_descr,
                                          yrrepair1_how,
                                          yrrepair1_notes,
                                          yrrepair2_notes,
                                          yrrepair3_notes,
                                          yrrepair4_notes,
                                          yrrepair5_notes,
                                          yrrepair1_scope)
                                        
             VALUES (
                     b.bridge_number,
                     substr(b.rr_active_line,1,5),
                     b.rr_deck_type,
                     Convert_to_number (b.rr_lr_limiting_speed),
                     convert_to_number (b.rr_lr_rating_factor_4axle),
                     convert_to_number (b.rr_lr_rating_factor_e80),
                     convert_to_number (b.rr_lr_rating_factor_veh3),
                     convert_to_number (b.rr_lr_rating_factor_veh4),
                     convert_to_number (b.rr_lr_speed_4axle),
                     convert_to_number (b.rr_lr_speed_e80),
                     convert_to_number (b.rr_lr_speed_veh3),
                     convert_to_number (b.rr_lr_speed_veh4),
                     convert_to_number (b.rr_lr_vehicle3),
                     convert_to_number (b.rr_lr_vehicle4),
                     convert_to_number (b.rr_lr_vehweight_4axle),
                     convert_to_number (b.rr_lr_vehweight_e80),
                     convert_to_number (b.rr_lr_weight_4axle),
                     convert_to_number (b.rr_lr_weight_e80),
                     convert_to_number (b.rr_lr_weight_veh3),
                     convert_to_number (b.rr_lr_weight_veh4),
                     b.rr_operator,
                     b.rr_route_number,
                     b.rr_track_alignment,
                     convert_to_number (b.rr_track_class),
                     convert_to_number (b.rr_track_speed_freight),
                     convert_to_number (b.rr_track_speed_passenger),
                     b.rr_track_surface,
                     b.rr_track_type,
                     b.structure_type_description,
                     b. yrrepair1_how,
                     b.yrrepair1_notes,
                     b.yrrepair2_notes,
                     b.yrrepair3_notes,
                     b.yrrepair4_notes,
                     b.yrrepair5_notes,
                     CASE WHEN length( b.yrrepair1_scope) = 1 THEN NULL -- Remove extra character at end of string
                          ELSE 
                     substr(b.yrrepair1_scope, 1, length( b.yrrepair1_scope) -1  )
                     END )            
                LOG ERRORS INTO RAIL_BRIDGES_ERROR_LOG
                        ('INSERT RAIL BRIDGE ' || g_start_time)
                        REJECT LIMIT UNLIMITED;

        commit_count := commit_count + 1;

        IF commit_count > 100
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;



    SELECT COUNT (*) INTO cntr FROM rail_bridges_staging;

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
