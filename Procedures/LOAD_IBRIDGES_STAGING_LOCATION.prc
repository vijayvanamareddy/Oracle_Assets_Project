CREATE OR REPLACE PROCEDURE load_ibridges_staging_location
IS
    /**********************************************************************
    This procedure loads the ibridges staging table with location columns from metrans.
    It is run as part of the ibridges_weekly_refresh on the weekends


   9/4/2015 - SH - Added element_id of railroad route into element_id_on_structure for railroad bridges
   9/8/2015 - SH - Added procedure to determine if element_id from metrans is on a highway or rail route.
                   If the type of service on the bridge is a railroad
                   and the route type of the element is also a railroad, then the element will be stored  in the element_id_on_structure.
                   If the type of service on the bridge is a railroad or pedestrian/bicycle, and the element is a highway route,
                   it is stored ‘under’ the bridge in the roads_associated table.  This is done in the load_bridge_roads procedure.
    9/15/15 - SH - Add the route_type_on_structure to the bridges table indicating if the element_id_on_structure is a 'HIGHWAY' or a 'RAIL' route
    6/6/2016  SH - copy load_bridges_from_metrans for inspect tech
              Remove segment_id, add begin_section_offset, end_section_offset
    7/11/2016 SH - Add standard error handling
    7/26/2016 SH - Get the latitude and longitude from InspecTech if the bridge is not in Metrans (JP Request)
    9/7/16    SH - Remove update of the offset from METrans.  Replaced by Milepoint from InspectTech (Cindy Owings request)
    11/22/16 SH - Get latitude and longitude from InspectTech based on decision Asset Location data will also be officially stored in InspectTech
    12/19/16 SH - Remove getting lat/long from this procedure as it is now done in load_ibridges_staging
                  When type_of_service_on is missing, we did not get a section_id.  Added a check for route_type = 'HIGHWAY' to handle this case.
    02-17-17 SH - Add the metrans offset back in.  Needed to calculate the location of the bridge on primary/alternate routes - Ed Beckwith request
                  New column named milepoint will refer to the milepoint on the primary route and come from InspectTech
                  offset will refer to the offset of the bridge on the element and come from METrans
    05-03-17 SH - Write unhandled exceptions to data_exception table
    07-05-18 SH - Modify reference to roadway_sections_history table to use roadway_sections view in preparation for adding rail, trail, ferry routes
    11-28-18 SH - Modify  references to roadway_sections view to roadway_sections_history table where end_date is null
                   and highways view to use highways_history table where end_date is null in preparation for going to full network
    01-21-19 SH - Modify references to highway network to use complete network and GIS Segmentation
                    Get section_id for rail bridges
    03-25-19 SH - Move version in wh_assets_dev to test
    09-23-19 SH - Reorganizing and cleaning up procedure - get route type from elements, section id for trail routes
    12-06-19 SH - Add MTRNS_ASSETNO (bridge pointer) of road on the bridge to support Bridge Portal Underclearances
    06-21-21 SH - Round offset to 3 digits in procedure Get_section_id to support METRANS change to thousandth (0.001) of a mile
    ************************************************************************************************************/


    CURSOR brdg
    IS
          SELECT v_nm_brdg_nw bridge_num,
                 ne_id_of   element_id,
                 nm_begin_mp offset,
                 iit_primary_key metrans_assetno,
                 br.type_of_service_on
            FROM v_nm_brdg_nw@metrans m, ibridges_staging br
           WHERE v_nm_brdg_nw = br.bridge_number
        ORDER BY v_nm_brdg_nw;

    cntr                       NUMBER := 0;
    start_time                 DATE := SYSDATE;
    g_sqlmsg                   VARCHAR2 (1000) := NULL;


    sect_id                    NUMBER;
    bsect_offset               NUMBER;
    esect_offset               NUMBER;

    troute_type_on_structure   ibridges_history.route_type_on_structure%TYPE;
    telement_wid               NUMBER;
    tprimary_route_number      ibridges_history.primary_route_number%TYPE;
    tprimary_route_name        ibridges_history.primary_route_name%TYPE;

    PROCEDURE Get_Element_Attributes (el_id     IN     NUMBER,
                                      el_wid       OUT NUMBER,
                                      rtenum       OUT VARCHAR,
                                      rtename      OUT VARCHAR,
                                      rtetype      OUT VARCHAR2)
    IS
        -- Get the element_wid, Primary Route Number, Route Name, Route Type from the ELEMENTS view
        err        VARCHAR2 (100);
        rte_type   VARCHAR2 (1);
    BEGIN
        el_wid := NULL;
        rtenum := NULL;
        rtename := NULL;
        rtetype := NULL;

        SELECT element_wid,
               primary_route_number,
               primary_route_name,
               route_type
          INTO el_wid,
               rtenum,
               rtename,
               rte_type
          FROM elements e
         WHERE e.element_id = el_id;

        CASE
            WHEN rte_type IN ('I', 'N')
            THEN
                rtetype := 'HIGHWAY';
            WHEN rte_type = 'T'
            THEN
                rtetype := 'RAIL';
            WHEN rte_type = 'B'
            THEN
                rtetype := 'TRAIL';
            ELSE
                rtetype := NULL;
        END CASE;
    EXCEPTION
        WHEN OTHERS
        THEN
            err :=
                   'Error num :'
                || TO_CHAR (SQLCODE)
                || ' '
                || SUBSTR (SQLERRM, 1, 70);

            INSERT INTO data_exceptions (table_name,
                                         error_condition,
                                         test_procedure,
                                         test_date,
                                         assessment,
                                         column_name1,
                                         column_value1,
                                         column_name2,
                                         column_value2)
                 VALUES ('ibridge_staging',
                         err,
                         $$PLSQL_UNIT,
                         start_time,
                         'EXCEPTION',
                         'PROCEDURE',
                         'Get_Element_Attributes',
                         'ELEMENT_NUMBER',
                         el_id);
    END;



    PROCEDURE Get_section_id (el_id          IN     NUMBER,
                              brdg_offst     IN     NUMBER,
                              bsect_offset      OUT NUMBER,
                              esect_offset      OUT NUMBER,
                              sec_id            OUT NUMBER)
    IS
        -- Gets the section id, begin/end section offsets from the sections table
        -- using the element id/ bridge offset from metrans
        counter   NUMBER;
        err       VARCHAR2 (100);
    BEGIN
        counter := 0;

        SELECT COUNT (*)     -- determine if offset lies on a section boundary
          INTO counter
          FROM sections s
         WHERE     el_id = s.element_id
               AND ROUND (brdg_offst, 3) >= s.begin_offset
               AND ROUND (brdg_offst, 3) <= S.end_offset;

        IF counter = 1                            -- not on a section boundary
        THEN
            SELECT s.section_id, s.begin_offset, s.end_offset
              INTO sec_id, bsect_offset, esect_offset
              FROM sections s
             WHERE     el_id = s.element_id
                   AND ROUND (brdg_offst, 3) >= s.begin_offset
                   AND ROUND (brdg_offst, 3) <= s.end_offset;
        END IF;

        IF counter > 1 -- on a section boundary, round to match the tide bridge table, the second section is chosen
        THEN
            SELECT s.section_id, s.begin_offset, s.end_offset
              INTO sec_id, bsect_offset, esect_offset
              FROM sections s
             WHERE     el_id = s.element_id
                   AND ROUND (brdg_offst, 3) >= S.BEGIN_OFFSET
                   AND ROUND (brdg_offst, 3) < S.END_OFFSET;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            err :=
                   'Error num :'
                || TO_CHAR (SQLCODE)
                || ' '
                || SUBSTR (SQLERRM, 1, 70);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT,
                                         COLUMN_NAME1,
                                         COLUMN_VALUE1,
                                         COLUMN_NAME2,
                                         COLUMN_VALUE2,
                                         COLUMN_NAME3,
                                         COLUMN_VALUE3)
                 VALUES ('ibridges_staging',
                         err,
                         $$PLSQL_UNIT,
                         start_time,
                         'EXCEPTION',
                         'PROCEDURE',
                         'Get_section_id',
                         'ELEMENT_ID',
                         EL_ID,
                         'OFFSET',
                         brdg_offst);
    END;
BEGIN
    FOR b IN brdg
    LOOP
        sect_id := NULL;
        bsect_offset := NULL;
        esect_offset := NULL;
        telement_wid := NULL;
        tprimary_route_number := NULL;
        tprimary_route_name := NULL;
        troute_type_on_structure := NULL;

        Get_Element_Attributes (b.element_id,
                                telement_wid,
                                tprimary_route_number,
                                tprimary_route_name,
                                troute_type_on_structure);

        Get_section_id (b.element_id,
                        b.offset,
                        bsect_offset,
                        esect_offset,
                        sect_id);


        UPDATE ibridges_staging
           SET element_id_on_structure = b.element_id,
               offset = b.offset,                -- add offset back in 2/17/17
               section_id = sect_id,
               begin_section_offset = bsect_offset,
               end_section_offset = esect_offset,
               route_type_on_structure = troute_type_on_structure,
               Highway_id_on_structure = telement_wid,
               primary_route_number = tprimary_route_number,
               primary_route_name = tprimary_route_name,
               mtrns_assetno = SUBSTR(b.metrans_assetno,1,7) || '-BRDG'
         WHERE bridge_number = b.bridge_num
           LOG ERRORS INTO ibridges_staging_error_log
                   (   'Load bridges staging from METRANS v_nm_brdg_nw'
                    || SYSDATE)
                   REJECT LIMIT 100;
    END LOOP;

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
               'Error during '
            || $$PLSQL_UNIT
            || ': '
            || SUBSTR (SQLERRM, 1, 400));
        RAISE_APPLICATION_ERROR (
            -20050,
            $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
END;
/
