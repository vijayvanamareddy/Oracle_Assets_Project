CREATE OR REPLACE PROCEDURE load_speed_zones_nonnum_rtes(
    last_snapshot_year          IN NUMBER)
IS
/**********************************************************************

This procedure uses the dissolve function to create speed zones table for non-numbered routes

10-15-20 SH Initial Version
10-21-2020 SH Prepare to move to prod - remove references to speed_zones_d temporary table  
**********************************************************************/
BEGIN
    DECLARE
        -- Declarations
        var_RetVal                SYS_REFCURSOR;
        var_I_WHERE               NVARCHAR2 (32767);
        var_I_COLUMNS             NVARCHAR2 (32767);
        l_route_number            NVARCHAR2 (100);
        l_begin_section_mp        NUMBER;
        l_end_section_mp          NUMBER;
        l_speedzn_id              NVARCHAR2 (100);
        l_element_id              NVARCHAR2 (100);
        l_town_name               NVARCHAR2 (100);
        l_region                  NVARCHAR2 (100);
        l_begin_node_id           NVARCHAR2 (100);
        l_begin_node_descr        NVARCHAR2 (100);
        l_direction               NVARCHAR2 (100);
        l_end_node_id             NVARCHAR2 (100);
        l_end_node_descr          NVARCHAR2 (100);
        l_route_name              NVARCHAR2 (100);
        l_element_length          NVARCHAR2 (100);
        l_end_element_milepoint   NVARCHAR2 (100);
        l_speed                   NVARCHAR2 (100);
        l_cmp                     NVARCHAR2 (100);
        l_street_name             NVARCHAR2 (100);
        l_street_prefix           NVARCHAR2 (100);
        l_street_type             NVARCHAR2 (100);

        l_metrans_route           NUMBER (9);
        l_rt_last_update          DATE;
        l_rt_updated_by           VARCHAR2 (30);

        l_sz_descr                VARCHAR2 (500);
        l_sz_effective_date       DATE;
        l_sz_last_update          DATE;
        l_sz_updated_by           VARCHAR2 (30);

        l_begin_element_mp        NUMBER;
        l_start_offset            NUMBER;
        l_end_offset              NUMBER;

        commit_count              NUMBER := 0;
        cntr                      NUMBER := 0;

        g_start_time              DATE := SYSDATE;
        g_owner                   VARCHAR2 (20) := 'WH_ASSETS';
        g_jobname                 VARCHAR2 (30) := 'LOAD_SPEED_ZONES_NONNUM_RTES';
        g_object                  VARCHAR2 (20) := 'SPEED_ZONES';
        g_sqlmsg                  VARCHAR2 (500) := NULL;
        

        FUNCTION Get_Metrans_RouteNum (route_number IN VARCHAR2)
            RETURN NUMBER
        IS
            err         VARCHAR2 (100);
            mroutenum   NUMBER := NULL;
        BEGIN
            SELECT NE_ID
              INTO mroutenum
              FROM NM_ELEMENTS@METRANS
             WHERE NE_TYPE = 'G' AND ne_unique = route_number;

            RETURN mroutenum;
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
                     VALUES ('speed zones',
                             err,
                             $$PLSQL_UNIT,
                             g_start_time,
                             'EXCEPTION',
                             'FUNCTION',
                             'Get_Metrans_RouteNum',
                             'Route Number',
                             route_number);
        END;

        PROCEDURE Get_Metrans_Route_Dates (ele_id          IN     NUMBER,
                                           spz_id          IN     NUMBER,
                                           date_modified      OUT DATE,
                                           modified_by        OUT VARCHAR2)
        IS
            err   VARCHAR2 (100);
        BEGIN
            SELECT DISTINCT NM_DATE_MODIFIED, NM_MODIFIED_BY
              INTO date_modified, modified_by
              FROM NM_MEMBERS@METRANS
             WHERE     NM_NE_ID_OF = ele_id
                   AND NM_NE_ID_IN = spz_id
                   AND NM_OBJ_TYPE = 'SPZN';
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
                                             column_value2,
                                             column_name3,
                                             column_value3)
                     VALUES ('speed zones',
                             err,
                             $$PLSQL_UNIT,
                             g_start_time,
                             'EXCEPTION',
                             'PROCEDURE',
                             'Get_Metrans_Route_Dates',
                             'Element ID',
                             ele_id,
                             'Speed Zone ID',
                             spz_id);
        END;

        PROCEDURE Get_Metrans_Spzn_Dates (eleid      IN     NUMBER,
                                          spzid      IN     NUMBER,
                                          descr         OUT VARCHAR,
                                          eff_date      OUT DATE,
                                          mod_date      OUT DATE,
                                          mod_by        OUT VARCHAR2)
        IS
            err   VARCHAR2 (100);
        BEGIN
            SELECT DISTINCT COMMENTS,
                            EFFECTIVE_DATE,
                            UPDATE_DATE,
                            IIT_MODIFIED_BY
              INTO descr,
                   eff_date,
                   mod_date,
                   mod_by
              FROM V_NM_SPZN_NW@METRANS
             WHERE IIT_NE_ID = spzid AND NE_ID_OF = eleid;
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
                                             column_value2,
                                             column_name3,
                                             column_value3)
                     VALUES ('speed zones',
                             err,
                             $$PLSQL_UNIT,
                             g_start_time,
                             'EXCEPTION',
                             'PROCEDURE',
                             'Get_Metrans_Spzn_Dates',
                             'Element ID',
                             eleid,
                             'Speed Zone ID',
                             spzid);
        END;
        
        PROCEDURE Compute_offsets(section_bmp  IN NUMBER,
                                  element_emp  IN NUMBER, 
                                  section_emp  IN NUMBER,
                                  element_len  IN NUMBER,
                                  soffset      OUT NUMBER,
                                  eoffset      OUT NUMBER)
        IS
           element_bmp  NUMBER;
           BEGIN
         

           element_bmp := element_emp - element_len;

            soffset :=
                CASE
                    WHEN element_bmp = section_bmp -- speed zone starts on node boundary
                    THEN 0
                    ELSE (section_bmp - element_bmp) -- speed zone does not start on node boundary
                END;



            eoffset :=
                CASE
                    WHEN element_emp = section_emp -- speed zone ends on node boundary
                    THEN 0
                    ELSE (section_emp - element_bmp) -- speed zone does not end on node boundary, how far is it from the begin node
                END;
     END;
 
      
   
    BEGIN


        -- Initialization
     
        var_I_WHERE :=
            'snapshot_year = ' || last_snapshot_year || ' AND  SPEEDZN_ID IS NOT NULL and ROUTE_TYPE = ''I''';

        var_I_COLUMNS :=
            'SPEEDZN_ID, ELEMENT_ID, STREET_NAME,
                                STREET_NAME_PREFIX,
                                STREET_NAME_SUFFIX,ELEMENT_LENGTH, END_ELEMENT_MILEPOINT, TOWN_NAME, MAINTENANCE_REGION, BEGIN_NODE_ID, BEGIN_NODE_DESCRIPTION, DIRECTION, END_NODE_ID, END_NODE_DESCRIPTION, ROUTE_NAME, SPEED, CUMULATIVE_MILEPOINT_ORDER';

        -- Call
        var_RetVal :=
            WH_ASSETS.F_DISSOLVE_ROUTE (I_WHERE     => var_I_WHERE,
                                        I_COLUMNS   => var_I_COLUMNS);

    

        LOOP
            FETCH var_RetVal
                INTO l_route_number,
                     l_begin_section_mp,
                     l_end_section_mp,
                     l_speedzn_id,
                     l_element_id,
                     l_street_name,             
                     l_street_prefix,           
                     l_street_type,   -- STREET_NAME_SUFFIX      
                     l_element_length,
                     l_end_element_milepoint,
                     l_town_name,
                     l_region,
                     l_begin_node_id,
                     l_begin_node_descr,
                     l_direction,
                     l_end_node_id,
                     l_end_node_descr,
                     l_route_name,
                     l_speed,
                     l_cmp;

            EXIT WHEN var_RetVal%NOTFOUND;


            l_metrans_route := Get_Metrans_RouteNum (l_route_number);

            Get_Metrans_Route_Dates (l_element_id,
                                     l_speedzn_id,
                                     l_rt_last_update,
                                     l_rt_updated_by);

            Get_Metrans_Spzn_Dates (l_element_id,
                                    l_speedzn_id,
                                    l_sz_descr,
                                    l_sz_effective_date,
                                    l_sz_last_update,
                                    l_sz_updated_by);


            Compute_offsets (l_begin_section_mp,l_end_element_milepoint, l_end_section_mp,l_element_length,l_start_offset,l_end_offset);
            
       
            INSERT INTO SPEED_ZONES (ASSET,
                                       ASSET_DESCR,
                                       BMP,
                                       DISTANCE,
                                       END_DESCR,
                                       END_ELEMENT_MP,
                                       END_MP,
                                       END_NODE,
                                       END_OFFSET,
                                       LENGTH,
                                       REGION,
                                       ROUTE,
                                       RTE_NAME,
                                       RT_LAST_UPDATE,
                                       RT_UPDATED_BY,
                                       SEQ_NO,
                                       SPEED,
                                       SPEED_ZONE_ID,
                                       START_DESCR,
                                       START_NODE,
                                       START_OFFSET,
                                       STREET_NAME,
                                       STREET_PREFIX,
                                       STREET_TYPE,
                                       SZ_DESCR,
                                       SZ_EFFECTIVE_DATE,
                                       SZ_GROUP,
                                       SZ_LAST_UPDATE,
                                       SZ_UPDATED_BY,
                                       TOWN)
                     VALUES (
                                l_element_id,                         -- asset
                                l_route_name,                   -- asset_descr
                                l_begin_section_mp,                     -- BMP
                                l_end_section_mp - l_begin_section_mp, --                  DISTANCE,
                                l_end_node_descr,
                                l_end_element_milepoint,
                                l_end_section_mp,
                                l_end_node_id,
                                l_end_offset,                   -- END_OFFSET,
                                l_element_length,
                                l_region,
                                l_metrans_route, -- ROUTE number (nm_elements.ne_id),
                                l_route_number,                    --RTE_NAME,
                                l_rt_last_update,
                                l_rt_updated_by,
                                l_cmp,                              -- SEQ_NO,
                                l_speed,                             -- SPEED,
                                l_speedzn_id,                -- SPEED_ZONE_ID,
                                l_begin_node_descr,            -- START_DESCR,
                                l_begin_node_id,                -- START_NODE,
                                l_start_offset,
                                l_street_name,
                                l_street_prefix,
                                l_street_type,
                                l_sz_descr,
                                TO_DATE (
                                    TO_CHAR (l_sz_effective_date,
                                             'MM/DD/YYYY'),
                                    'MM/DD/YYYY'),              -- remove time
                                'NON-NUMBERED',                 -- spzn_grp,        
                                TO_DATE (
                                    TO_CHAR (l_sz_last_update, 'MM/DD/YYYY'),
                                    'MM/DD/YYYY'),            -- remove time ,
                                l_sz_updated_by,
                                l_town_name)                           -- TOWN
                    LOG ERRORS INTO SPEED_ZONES_ERROR_LOG
                            ('LOAD_SPEED_ZONES_NONNUM_RTES ' || SYSDATE)
                            REJECT LIMIT 100;

            commit_count := commit_count + 1;

            IF commit_count > 10000
            THEN
                COMMIT;
                commit_count := 0;
            END IF;
    
        END LOOP;

        COMMIT;
        SELECT COUNT (*) INTO cntr FROM SPEED_ZONES;

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
end;
/
