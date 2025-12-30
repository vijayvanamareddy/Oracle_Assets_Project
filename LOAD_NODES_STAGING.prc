CREATE OR REPLACE PROCEDURE load_nodes_staging
IS
    /***************************************************************************************
    This procedure loads the nodes table from MeTrans, Crash, and the GIS system

     08-25-17 SH Initial Version
     08-30-17 SH Join to highways to ensure we are only getting nodes on the highway network
     09-19-17 SH Add error log
     12-20-17 SH Fix bug where mp on primary route is incorrect.  Remove check of direction.
     12-28-17 SH Major overhaul - added several columns and Dtgispd.nodes as a source
     04-19-18 SH Add nodes from rail, trail, and ferry route systems.  Rename table to all_nodes, procedure to load_all_nodes
     06-19-18 SH Modify source for federal_urban_group from gis node_mpo to NODE_FEDERAL_GROUP
                to pick up codes 0 (Rural) and 3 (Federal Small Urban) which J. Prendergast added
     07-05-18 SH Calculate AADT from elements and sections tables, not highways and roadway_sections, use all_nodes_on_route view not nodes_on_route
     07-13-18 SH Add primary route name
     07-24-18 SH Get no_of_legs from GIS System Dtgispd.nodes instead of calculating them using the tide algorithms
                 Will be the number of incoming legs on highway elements only
                 Modify the calculation of a node's FAADT so that it excludes the FAADTs of an element on a ferry route
     08-09-18 SH Rename all_nodes table to nodes
                 Rename procedure name from load_all_nodes to load_nodes
     03-05-19 SH Modify procedure to load_nodes_staging to keep history and prepare for snapshot
     07-09-19 SH Copy from Prod - Look up FFC Code from wh_common.DIM_FED_FUNC_CLASS using the function F_GET_FFC_CODE
     12-13-21 SH Add columns signal_id, signal_type, offset to support TRAFFIC_SIGNALS 
     06-01-22 SH Get FAADT from CAS instead of calculating it here.  Task:  DOTDW-665
     01-31-23 SH If the node type from CAS is null, make it P (primary) DOTDW-761
    ****************************************************************************************/



    commit_count                  NUMBER (7) := 0;
    cntr                          NUMBER (7) := 0;

    g_start_time                  DATE := SYSDATE;
    g_owner                       VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname                     VARCHAR2 (30) := 'LOAD_NODES_STAGING';
    g_object                      VARCHAR2 (20) := 'NODES_STAGING';
    g_sqlmsg                      VARCHAR2 (500) := NULL;

    federal_urb_rural             nodes_staging.federal_urban_rural%TYPE;
    state_urb_rural               nodes_staging.state_urban_rural%TYPE;
    nhs                           nodes_staging.nhs_status%TYPE;
    fed_urb_rural_description     nodes_staging.federal_urban_rural_descr%TYPE;
    state_urb_rural_description   nodes_staging.state_urban_rural_descr%TYPE;
    fed_urb_group_description     nodes_staging.federal_urban_group_descr%TYPE;
    ffc                           nodes_staging.federal_functional_class%TYPE;
    ffc_descr                     nodes_staging.federal_functional_class_descr%TYPE;
    cnty_name1                    nodes_staging.county_name1%TYPE;
    cnty_code1                    nodes_staging.county_code1%TYPE;
    twn_name1                     nodes_staging.town_name1%TYPE;
    regioncode1                   nodes_staging.region1%TYPE;
    regionname1                   nodes_staging.region_name1%TYPE;
    cnty_name2                    nodes_staging.county_name2%TYPE;
    cnty_code2                    nodes_staging.county_code2%TYPE;
    twn_name2                     nodes_staging.town_name2%TYPE;
    regioncode2                   nodes_staging.region2%TYPE;
    regionname2                   nodes_staging.region_name2%TYPE;
    el_id                         nodes_staging.element_id%TYPE;
    sect_id                       nodes_staging.section_id%TYPE;
    oset                          NUMBER;
    rt_type                       nodes_staging.route_type%TYPE;
    hass_descrip                  nodes_staging.hass_descr%TYPE;

    CURSOR nod
    IS
        SELECT no_node_id AS node_id,
               no_descr   AS node_description,
               node       AS town_line_node
          FROM devmetrn.nm_nodes@metrans
               LEFT OUTER JOIN v_townlinenodes@metrans ON no_node_id = node
         WHERE no_node_id IN (SELECT begin_node_id FROM elements
                              UNION
                              SELECT end_node_id FROM elements);

    CURSOR crsh
    IS
        SELECT node AS NODE_ID, faadt, mev, NVL(node_type, 'P') as node_type FROM nodes@crash;

    CURSOR gis
    IS
        SELECT node_id,
               fedfunccls_major,
               Federal_urbanized,
               node_federal_group,               -- replaced 6/19/18 node_mpo,
               state_urbanized,
               signalized,
               signal_id,
               signal_beacon,
               prirtecode,
               node_primary_rtname,
               node_mp,
               priority_major,
               Jurisdictn_major,
               latitude,
               longitude,
               node_nhs,
               towncode1,
               towncode2,
               region1,
               region2,
               countycode1,
               countycode2,
               sum_incnt                    -- number of incoming highway legs
          FROM medot.nodes@gis;



    PROCEDURE Get_town_county_region (twn_code    IN     NUMBER,
                                      twn_name       OUT VARCHAR2,
                                      cnty_name      OUT VARCHAR2,
                                      reg_no         OUT NUMBER,
                                      reg_name       OUT VARCHAR2)
    IS
        err   VARCHAR2 (100);
    BEGIN
        SELECT county,
               townname,
               maintenance_region,
               mreg_name
          INTO cnty_name,
               twn_name,
               reg_no,
               reg_name
          FROM wh_common.dim_towns t
         WHERE t.towncode = twn_code;
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
                 VALUES ('NODES_STAGING',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'FUNCTION',
                         'Get_town_county_region',
                         'TOWN_CODE',
                         twn_code);
    END;

    FUNCTION Get_Hass (sect_id NUMBER)
        RETURN VARCHAR2
    IS
        err          VARCHAR2 (400);
        hass_descr   VARCHAR2 (100) := NULL;
    BEGIN
        SELECT hass_description
          INTO hass_descr
          FROM sections s
         WHERE sect_id = s.section_id;

        RETURN hass_descr;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN '?';
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
                                         COLUMN_VALUE2)
                 VALUES ('NODES',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'FUNCTION',
                         'Get_HASS',
                         'SECTION_ID',
                         sect_id);
    END;



    PROCEDURE Get_element_and_section_id (nodeid      IN     NUMBER,
                                          rte_num     IN     VARCHAR,
                                          elementid      OUT NUMBER,
                                          sectionid      OUT NUMBER,
                                          ofset         OUT NUMBER)
    IS
        -- Get the element_id, offset, section_id  given a node_id and route_number
        err    VARCHAR2 (100);
        bcnt   NUMBER := 0;
        ecnt   NUMBER := 0;
        
    BEGIN
        elementid := NULL;
        sectionid := NULL;
        ofset := NULL;

        SELECT COUNT (*)
          INTO bcnt
          FROM nodes_on_route n
         WHERE     n.node_id = nodeid
               AND n.route_number = rte_num
               AND n.node_position = 'BEGIN';

        IF bcnt = 1                           -- node_id  matches a begin_node
        THEN
            SELECT element_id, section_id, offset
              INTO elementid, sectionid, ofset
              FROM nodes_on_route n
             WHERE     n.node_id = nodeid
                   AND n.route_number = rte_num
                   AND n.node_position = 'BEGIN';
        ELSE
            SELECT COUNT (*)                   -- node_id  matches an end_node
              INTO ecnt
              FROM nodes_on_route n
             WHERE     n.node_id = nodeid
                   AND n.route_number = rte_num
                   AND n.node_position = 'END';

            IF ecnt = 1
            THEN
                SELECT element_id, section_id, offset
                  INTO elementid, sectionid, ofset
                  FROM nodes_on_route n
                 WHERE     n.node_id = nodeid
                       AND n.route_number = rte_num
                       AND n.node_position = 'END';
            END IF;
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
                 VALUES ('NODES',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'EXCEPTION',
                         'FUNCTION',
                         'Get_Element_id',
                         'NODE_ID',
                         nodeid,
                         'ROUTE NUMBER',
                         rte_num);
    END;
BEGIN
    EXECUTE IMMEDIATE 'truncate table nodes_staging';

    EXECUTE IMMEDIATE 'truncate table nodes_error_log';

    FOR n IN nod
    LOOP
        INSERT INTO nodes_staging (node_id, node_description, townline_node)
                 VALUES (
                            n.node_id,
                            n.node_description,
                            CASE
                                WHEN n.town_line_node IS NOT NULL THEN 'YES'
                            END)
                LOG ERRORS INTO nodes_error_log
                        ('Insert Nodes ' || SYSDATE)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;
    commit_count := 0;


    FOR c IN crsh
    LOOP
        UPDATE nodes_staging n
           SET n.mev = c.mev, n.node_type = c.node_type, n.factored_aadt = c.faadt
         WHERE n.node_id = c.node_id
           LOG ERRORS INTO nodes_error_log
                   ('Update Nodes From Crash' || SYSDATE)
                   REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;

    FOR g IN gis
    LOOP
        federal_urb_rural :=
            CASE
                WHEN g.Federal_urbanized = 'N' THEN 1
                WHEN g.Federal_urbanized = 'Y' THEN 2
                ELSE NULL
            END;

        state_urb_rural :=
            CASE
                WHEN g.state_urbanized = 'N' THEN 1
                WHEN g.state_urbanized = 'Y' THEN 2
                ELSE NULL
            END;

        fed_urb_rural_description :=
            highways_description_lookup ('URB_CODE', federal_urb_rural, 30);

        state_urb_rural_description :=
            highways_description_lookup ('URB_CODE', state_urb_rural, 5);

        fed_urb_group_description :=
            Highways_description_lookup ('URB_GROUP',
                                         g.node_federal_group,
                                         20);



        nhs :=
            CASE
                WHEN g.node_nhs = 'N' THEN 'NOT ON NHS'
                WHEN g.node_nhs = 'Y' THEN 'ON NHS'
                ELSE NULL
            END;

        -- The GIS System stores the ffc description for federal functional class for nodes.
        -- We need to look up the code based on the description 
       
        ffc_descr := g.fedfunccls_major;
       
        ffc := F_Get_FFC_CODE(ffc_descr);

        cnty_code1 := SUBSTR (g.towncode1, 1, 2); -- first 2 characters of town_code
        Get_town_county_region (g.towncode1,
                                twn_name1,
                                cnty_name1,
                                regioncode1,
                                regionname1);

        IF g.towncode2 IS NOT NULL
        THEN
            cnty_code2 := SUBSTR (g.towncode2, 1, 2); -- first 2 characters of town_code
            Get_town_county_region (g.towncode2,
                                    twn_name2,
                                    cnty_name2,
                                    regioncode2,
                                    regionname2);
        ELSE
            cnty_code2 := NULL;
            twn_name2 := NULL;
            cnty_name2 := NULL;
            regioncode2 := NULL;
            regionname2 := NULL;
        END IF;

        IF g.prirtecode IS NOT NULL
        THEN
            Get_element_and_section_id (g.node_id,
                                        g.prirtecode,
                                        el_id,
                                        sect_id,
                                        oset);
            rt_type := F_Get_route_type (g.prirtecode);
        ELSE
            el_id := NULL;
            sect_id := NULL;
            oset:= NULL;
            rt_type := NULL;
        END IF;

        IF sect_id IS NOT NULL
        THEN
            hass_descrip := Get_hass (sect_id);
        ELSE
            hass_descrip := NULL;
        END IF;

        UPDATE nodes_staging n
           SET n.federal_urban_rural = federal_urb_rural,
               n.federal_functional_class_descr = ffc_descr,
               n.federal_functional_class = ffc,
               n.state_urban_rural = state_urb_rural,
               n.traffic_signal = g.signalized,
               n.signal_id = g.signal_id,
               n.signal_type = g.signal_beacon,
               n.primary_route_num = g.prirtecode,
               n.primary_route_name = g.node_primary_rtname,
               n.primary_route_mp = g.node_mp,
               n.priority = g.priority_major,
               n.jurisdiction = g.jurisdictn_major,
               n.latitude = g.latitude,
               n.longitude = g.longitude,
               n.nhs_status = nhs,
               n.no_of_legs = g.sum_incnt,
               federal_urban_rural_descr = fed_urb_rural_description,
               state_urban_rural_descr = state_urb_rural_description,
               n.federal_urban_group = g.node_federal_group,
               n.federal_urban_group_descr = fed_urb_group_description,
               n.hass_descr = hass_descrip,
               n.town_code1 = g.towncode1,
               n.town_code2 = g.towncode2,
               n.town_name1 = twn_name1,
               n.town_name2 = twn_name2,
               n.region1 = regioncode1,
               n.region2 = regioncode2,
               n.region_name1 = regionname1,
               n.region_name2 = regionname2,
               n.county_code1 = cnty_code1,
               n.county_code2 = cnty_code2,
               n.county_name1 = cnty_name1,
               n.county_name2 = cnty_name2,
               n.element_id = el_id,
               n.section_id = sect_id,
              n.offset = oset,
               n.route_type = rt_type
         WHERE n.node_id = g.node_id
           LOG ERRORS INTO nodes_error_log
                   ('Update Nodes From GIS' || SYSDATE)
                   REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;



    SELECT COUNT (*) INTO cntr FROM nodes_staging;

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
