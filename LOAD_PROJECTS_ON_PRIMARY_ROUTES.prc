CREATE OR REPLACE PROCEDURE Load_Projects_On_Primary_Routes
IS
/**********************************************************************
This procedure uses the dissolve function to create the locations of projects
on the primary routes


01-17-24  SH Initial Version


**********************************************************************/
BEGIN
    DECLARE
      
        g_start_time                  DATE := SYSDATE;
        g_owner                       VARCHAR2 (20) := 'WH_ASSETS';
        g_jobname                     VARCHAR2 (30) := 'LOAD_PROJECTS_ON_PRIMARY_ROUTE';
        g_object                      VARCHAR2 (30) := 'PROJECTS_ON_PRIMARY_ROUTES';
        g_sqlmsg                      VARCHAR2 (500) := NULL;

        var_RetVal                    SYS_REFCURSOR;

        l_route_id                    NVARCHAR2 (100);
        l_bmp                         NVARCHAR2 (50);
        l_emp                         NVARCHAR2 (50);
        l_table                       NVARCHAR2 (100);
        l_columns                     NVARCHAR2 (32767);
        l_where                       NVARCHAR2 (32767);


        l_route_number                NVARCHAR2 (100);
        l_route_number_psn            NVARCHAR2 (100);
 
        l_begin_section_mp            NUMBER;
        l_end_section_mp              NUMBER;

        l_psn                         NVARCHAR2 (100);
  

        commit_count                  NUMBER := 0;
        cntr                          NUMBER := 0;

        last_snapshot_year            NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE DISSOLVED_PROJECTS_ON_PRIMARY_ROUTE';

       EXECUTE IMMEDIATE 'TRUNCATE TABLE DISSOLVED_POPR_ERROR_LOG';

        -- Initialization

        l_route_id := 'route_number_psn';
        l_bmp := 'begin_mp';
        l_emp := 'end_mp';
        l_table := 'projects_on_route';



        l_WHERE := 'PRIMARY = ''Y'' AND ASSET_TYPE = ''ROAD'' AND PSN = ''78293'' ';


        l_COLUMNS :=
            'PSN, ROUTE_NUMBER';

        var_RetVal :=
            WH_ASSETS.F_DISSOLVE (l_route_id,
                                  l_bmp,
                                  l_emp,
                                  l_table,
                                  l_columns,
                                  l_where);

        LOOP

            FETCH var_RetVal
                INTO l_route_number_psn,
                     l_begin_section_mp,
                     l_end_section_mp,
                     l_psn,
                     l_route_number;
                     
  
            EXIT WHEN var_RetVal%NOTFOUND;



            INSERT INTO dissolved_projects_on_primary_route (  
                        psn,                           
                            route_number,
                            begin_mp,
                            end_mp)
                 VALUES (  l_psn,
                         l_route_number,
                         l_begin_section_mp,
                         l_end_section_mp)
                         LOG ERRORS INTO DISSOLVED_POPR_ERROR_LOG
                        ('load_projects_on_primary_route ' || g_start_time)
                        REJECT LIMIT 100;

            commit_count := commit_count + 1;

            IF commit_count > 10000
            THEN
                COMMIT;
                commit_count := 0;
            END IF;
        END LOOP;

        COMMIT;
  
           SELECT COUNT (*) INTO cntr from dissolved_projects_on_primary_route ;

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
    
END;
/
