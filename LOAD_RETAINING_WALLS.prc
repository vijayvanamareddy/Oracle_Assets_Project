CREATE OR REPLACE PROCEDURE load_retaining_walls
IS
    /**********************************************************************
    This procedure loads the retaining walls table with data from AssetWise
    to be used by the Mapviewer

      It reads the data from ext_retaining_walls

    10-06-2020 SH Initial Version

    Modification History:

    **********************************************************************/

    common_rundate                   DATE := SYSDATE;
    cntr                             NUMBER;
    surrogate_key                    NUMBER;
    procname                         VARCHAR2 (50) := 'LOAD_RETAINING_WALLS';
    num                              NUMBER;
    day_of_week                      VARCHAR2 (3);
    field_num                        NUMBER;
    errlog_count                     NUMBER;
    err_log_message                  VARCHAR2 (200);

    -- Temporary variables for columns to be converted to numeric

    tback_slope                      NUMBER;
    tface_angle                      NUMBER;
    tface_area_sf                    NUMBER;
    tfront_slope                     NUMBER;
    thcp                             NUMBER;
    thorizontal_offset_ft            NUMBER;
    tinspection_frequency_yrs        NUMBER;
    tlatitude                        NUMBER;
    tlongitude                       NUMBER;
    tmax_wall_height_ft              NUMBER;
    ttotal_length_ft                 NUMBER;
    tvertical_offset_ft              NUMBER;

    tinspection_date                 DATE;
    tnext_inspection_due             DATE;

    -- Temporary Variables to lookup descriptions

    descrip_len                      NUMBER;



  

    maintainer_description           retaining_walls.maintainer_descr%TYPE;
    owner_description                retaining_walls.owner_descr%TYPE;
    wall_type_description            retaining_walls.wall_type_descr%TYPE;
    facing_description               retaining_walls.facing_descr%TYPE;
    condition_rating_description     retaining_walls.condition_rating_descr%TYPE;
    stability_rating_description     retaining_walls.stability_rating_descr%TYPE;


    -- fe_id and max length of description



    fmaintainer                      NUMBER;
    lmaintainer                      NUMBER;

    fowner                           NUMBER;
    lowner                           NUMBER;

    fwall_type                       NUMBER;
    lwall_type                       NUMBER;

    ffacing                          NUMBER;
    lfacing                          NUMBER;

    fcondition_rating                NUMBER;
    lcondition_rating                NUMBER;

    fstability_rating                NUMBER;
    lstability_rating                NUMBER;


    CURSOR rw
    IS
        SELECT BACK_SLOPE,
               BRIDGE_NUMBER,
               CONDITION_RATING,
               CONSTRUCTION_TYPE,
               CULVERT_NUMBER,
               FACE_ANGLE,
               FACE_AREA,
               FACING,
               FRONT_SLOPE,
               FUNCTION_TYPE,
               HCP,
               HORIZONTAL_OFFSET,
               INSPECTION_FREQUENCY_YRS,
               LAST_INSPECTION_DATE,
               LATITUDE,
               LOCATION_DESCRIPTION,
               LONGITUDE,
               MAINTAINER,
               R.MAINTENANCE_REGION,
               MAX_WALL_HEIGHT_FT,
               C.MREG_NAME,   
               NEXT_INSPECTION_DUE,
               OWNER,
               ROUTE_NUMBER,
               SIDE_OF_CL,
               STABILITY_RATING,
               STREET,
               TOTAL_LENGTH_FT,
               r.TOWNCODE,
               c.townname,
               VENEER,
               VERTICAL_OFFSET,
               WALL_ID,
               WALL_NAME,
               WALL_TYPE,
               YEAR_BUILT
          FROM ext_retaining_walls  r
               LEFT OUTER JOIN wh_common.dim_towns c
                   ON r.towncode = c.towncode;


    PROCEDURE Lookup_fe_id_length (column_name    IN     VARCHAR2,
                                   insp_fe_id        OUT NUMBER,
                                   max_desc_len      OUT NUMBER)
    IS
    -- Procedure to Look up inspecTech field ID and longest length of description
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
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE RETAINING_WALLS';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE RETAINING_WALLS_ERROR_LOG';

    -- Get fe_id and max length of the description for each _descr column


    Lookup_fe_id_length ('MAINTAINER', fmaintainer, lmaintainer);

    Lookup_fe_id_length ('OWNER', fowner, lowner);
    Lookup_fe_id_length ('WALL_TYPE', fwall_type, lwall_type);
    Lookup_fe_id_length ('FACING', ffacing, lfacing);
    Lookup_fe_id_length ('CONDITION_RATING',
                         fcondition_rating,
                         lcondition_rating);
    Lookup_fe_id_length ('STABILITY_RATING',
                         fstability_rating,
                         lstability_rating);


    FOR rec IN rw
    LOOP
        -- Convert columns to numeric using function Convert_to_number
        tback_slope := Convert_to_number (rec.back_slope);
        tface_angle := Convert_to_number (rec.face_angle);
        tface_area_sf := Convert_to_number (rec.face_area);
        tfront_slope := Convert_to_number (rec.front_slope);
        thcp := Convert_to_number (rec.hcp);
        thorizontal_offset_ft :=  convert_to_number(replace (rec.horizontal_offset,q'*'*', NULL)) ;  -- strip off the ft symbol (')
        tinspection_frequency_yrs :=
            Convert_to_number (rec.inspection_frequency_yrs);
        tlatitude := Convert_to_number (rec.latitude);
        tlongitude := Convert_to_number (rec.longitude);
        tmax_wall_height_ft := Convert_to_number (rec.max_wall_height_ft);
        ttotal_length_ft := Convert_to_number (rec.total_length_ft);
        tvertical_offset_ft := Convert_to_number (rec.vertical_offset);

        -- Convert columns to date

        tinspection_date :=
            convert_to_date (SUBSTR (rec.last_inspection_date, 1, 10),
                             'mm-dd-yyyy');


        tnext_inspection_due :=
            convert_to_date (SUBSTR (rec.next_inspection_due, 1, 10),
                             'mm-dd-yyyy');



        -- Lookup Descriptions

        maintainer_description :=
            bridge_lookup (fmaintainer, rec.maintainer, lmaintainer);


        owner_description :=
            bridge_lookup (fowner, rec.owner, lowner);

        wall_type_description :=
            bridge_lookup (fwall_type, rec.wall_type, lwall_type);
        facing_description := bridge_lookup (ffacing, rec.facing, lfacing);
        condition_rating_description :=
            bridge_lookup (fcondition_rating,
                           rec.condition_rating,
                           lcondition_rating);
        stability_rating_description :=
            bridge_lookup (fstability_rating,
                           rec.stability_rating,
                           lstability_rating);

        INSERT INTO retaining_walls (back_slope,
                                     bridge_number,
                                     condition_rating_descr,
                                     conditon_rating,
                                     construction_type,
                                     culvert_number,
                                     face_angle,
                                     face_area_sf,
                                     facing,
                                     facing_descr,
                                     front_slope,
                                     function_type,
                                     hcp,
                                     horizontal_offset_ft,
                                     inspection_frequency_yrs,
                                     last_inspection_date,
                                     latitude,
                                     location_description,
                                     longitude,
                                     maintainer,
                                     maintainer_descr,
                                     maintenance_region,
                                     maintenance_region_descr,
                                     max_wall_height_ft,
                                     next_inspection_due,
                                     owner,
                                     owner_descr,
                                     route_number,
                                     side_of_centerline,
                                     stability_rating,
                                     stability_rating_descr,
                                     street,
                                     total_length_ft,
                                     towncode,
                                     town_name,
                                     veneer,
                                     vertical_offset_ft,
                                     wall_id,
                                     wall_name,
                                     wall_type,
                                     wall_type_descr,
                                     year_built)
             VALUES (tback_slope,
                     rec.bridge_number,
                     condition_rating_description,
                     rec.condition_rating,
                     rec.construction_type,
                     rec.culvert_number,
                     tface_angle,
                     tface_area_sf,
                     rec.facing,
                     facing_description,
                     tfront_slope,
                     rec.function_type,
                     thcp,
                     thorizontal_offset_ft,
                     tinspection_frequency_yrs,
                     tinspection_date,
                     tlatitude,
                     replace(rec.location_description, ';',','),  -- replace the ; with the , which was done to extract to csv file
                     tlongitude,
                     rec.maintainer,
                     maintainer_description,
                     trim(leading '0' from rec.maintenance_region),
                     rec.mreg_name,
                     tmax_wall_height_ft,
                     tnext_inspection_due,
                     rec.owner,
                     owner_description,
                     rec.route_number,
                     rec.side_of_cl,
                     rec.stability_rating,
                     stability_rating_description,
                     rec.street,
                     ttotal_length_ft,
                     rec.towncode,
                     rec.townname,
                     rec.veneer,
                     tvertical_offset_ft,
                     rec.wall_id,
                     rec.wall_name,
                     rec.wall_type,
                     wall_type_description,
                     REC.year_built)
                LOG ERRORS INTO retaining_walls_error_LOG
                        ('Load Retaining Walls ' || SYSDATE)
                        REJECT LIMIT 100;

        COMMIT;
    END LOOP;

    COMMIT;

    -- Check error logs for quality errors
    
    
   
    SELECT COUNT (*)
      INTO errlog_count
      FROM wh_assets.retaining_walls_error_log;

    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in retaining_walls_error_log';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'LOAD_RETAINING_WALLS',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('RETAINING_WALLS_ERROR_LOG',
                         'Invalid data - check error log',
                         procname,
                         common_rundate,
                         'QUALITY');

            COMMIT;
        END;
    END IF;

    SELECT COUNT (*) INTO cntr FROM RETAINING_WALLS;


    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
        OWNER         => 'WH_ASSETS',
        OBJECT_NAME   => 'RETAINING_WALLS',
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
