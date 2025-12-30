CREATE OR REPLACE PROCEDURE load_yr_over_yr_changes
IS
/**********************************************************************
This procedure compares attributes on the highway network between two contiguous years

Writes to table:  HIGHWAY_YR_YR_CHANGES

It is run as part of the weekly refresh process

04-13-21 SH Initial Version
05-27-21 SH Generalize procedure so can use to identify changes for JURISDICTION, FEDERAL_FUNCTIONAL_CLASS_DESCR, STATE_URBAN_RURAL_DESCR
02-23    SH Get column list from table,  HIGHWAY_YR_YR_CHANGE_COLUMNS     JIRA DOTDW-700
03-06-23 SH Only add new rows if they don't already exist
03-24-23 SH Get current snapshot year from function
**********************************************************************/

BEGIN
    DECLARE
        CV                   SYS_REFCURSOR;

        yr                   NUMBER;
        prev_yr              NUMBER;
        l_WHERE              VARCHAR2 (100);

        l_col_value          VARCHAR2 (40);
        l_column             VARCHAR2 (128);

        l_jurisdiction       VARCHAR2 (40);
        l_route_number       VARCHAR2 (7);
        l_town               VARCHAR2 (40);
        l_yr                 NUMBER;
        l_element_id         NUMBER;
        l_section_id         NUMBER;
        l_begin_section_mp   NUMBER;
        l_end_section_mp     NUMBER;
        l_other_col_value    VARCHAR2 (40);
        l_begin_overlap_mp   NUMBER;
        l_end_overlap_mp     NUMBER;

        g_start_time         DATE := SYSDATE;
        g_owner              VARCHAR2 (20) := 'WH_ASSETS';
        g_jobname            VARCHAR2 (30) := 'LOAD_YR_OVER_YR_CHANGES';
        g_object             VARCHAR2 (30) := 'HIGHWAY_YR_YR_CHANGES';
        g_sqlmsg             VARCHAR2 (500) := NULL;
        cntr                 NUMBER := 0;
        cntr_added           NUMBER  := 0;
        V_flat_file_counts_txt     VARCHAR2 (1000) := NULL;
        

        CURSOR column_list IS
            SELECT UPPER (COL_NAME) col FROM HIGHWAY_YR_YR_CHANGE_COLUMNS;

        CURSOR ranges_dissolved IS
            SELECT DISTINCT c.snapshot_year,
                            BEGIN_TOWN_MP,
                            END_TOWN_MP,
                            c.ROUTE_NUMBER,
                            TOWN_NAME,
                            c.change_column_value
              FROM changed_sections  c,
                   LATERAL (
                       SELECT t.snapshot_year,
                              t.ROUTE_NUMBER,
                              t.BEGIN_SECTION_MP     AS BEGIN_TOWN_MP,
                              t.END_SECTION_MP       AS END_TOWN_MP,
                              COLUMN1                TOWNNAME,
                              COLUMN2                JURISDICTION
                         FROM TABLE (
                                  WH_ASSETS.PKG_DISSOLVE.F_DISSOLVE_ROUTE (
                                      l_where,
                                      'TOWN_NAME',
                                      l_column)) t
                        WHERE     c.route_number = t.ROUTE_NUMBER
                              AND c.snapshot_year = t.snapshot_year
                              AND c.town_name = t.COLUMN1
                              AND c.change_column_value = t.column2);

        rec3                 ranges_dissolved%ROWTYPE;



        CURSOR ranges_other_yr IS
              SELECT snapshot_year,
                     route_number,
                     town_name,
                     CHANGE_COLUMN_VALUE,
                     MIN (begin_section_mp)     begin_range_mp,
                     MAX (end_section_mp)       end_range_mp
                FROM other_yr_sections
            GROUP BY snapshot_year,
                     route_number,
                     town_name,
                     CHANGE_COLUMN_VALUE;

        rec5                 ranges_other_yr%ROWTYPE;

        CURSOR final_result IS
            SELECT DISTINCT
                   ts.snapshot_year,
                   ts.route_number,
                   ts.town_name,
                   ts.CHANGE_COLUMN_VALUE,
                   S.CHANGE_COLUMN_VALUE    OTHER_YR_CHANGE_COLUMN_VALUE,
                   ts.element_id,
                   ts.section_id,
                   ts.begin_section_mp,
                   ts.end_section_mp,
                   CASE
                       WHEN s.begin_range_mp > ts.begin_section_mp
                       THEN
                           s.begin_range_mp
                       ELSE
                           ts.begin_section_mp
                   END                      overlap_start_mp,
                   CASE
                       WHEN s.end_range_mp < ts.end_section_mp
                       THEN
                           s.end_range_mp
                       ELSE
                           ts.end_section_mp
                   END                      overlap_end_mp
              FROM changed_sections  ts
                   JOIN other_yr_ranges s
                       ON     ts.route_number = s.route_number
                          AND ts.town_name = s.town_name
                          AND ts.snapshot_year <> s.snapshot_year
                          AND ts.CHANGE_COLUMN_VALUE <> s.CHANGE_COLUMN_VALUE
                          AND s.begin_range_mp < ts.end_section_mp
                          AND ts.begin_section_mp < s.end_range_mp
            UNION
            SELECT snapshot_year,
                   route_number,
                   town_name,
                   CHANGE_COLUMN_VALUE,
                   Other_YR_CHANGE_COLUMN_VALUE,
                   element_id,
                   section_id,
                   begin_section_mp,
                   end_section_mp,
                   begin_overlap_mp,
                   end_overlap_mp
              FROM other_yr_sections;

        rec6                 final_result%ROWTYPE;


       
    BEGIN
        EXECUTE IMMEDIATE 'truncate table changed_attributes';

        EXECUTE IMMEDIATE 'truncate table changed_sections';

        EXECUTE IMMEDIATE 'truncate table dissolved_ranges';

        EXECUTE IMMEDIATE 'truncate table other_yr_sections';

        EXECUTE IMMEDIATE 'truncate table other_yr_ranges';

        yr := F_GET_SNAPSHOT_YEAR;
        prev_yr := yr - 1;
        l_WHERE := 'snapshot_year in (' || prev_yr || ',' || yr || ')  
                        AND row_type = ''Element''';

        FOR cl IN column_list
        LOOP
            l_column := cl.col;

            OPEN CV FOR
                   'SELECT ROUTE_NUMBER,
           TOWN_NAME,
           '
                || l_column
                || '
           ,
           mtch
      FROM (SELECT DISTINCT ROUTE_NUMBER,
                            TOWN_NAME,
                            '
                || l_column
                || ','
                || prev_yr
                || '  mtch
              FROM V_COMPLETE_TRANSP_NETWORK
             WHERE snapshot_year = '
                || prev_yr
                || ' AND ROUTE_TYPE IN (''N'', ''I'')
            MINUS
            SELECT DISTINCT ROUTE_NUMBER,
                            TOWN_NAME,'
                || l_column
                || ','
                || prev_yr
                || '     mtch
              FROM V_COMPLETE_TRANSP_NETWORK
             WHERE snapshot_year = '
                || YR
                || ' AND ROUTE_TYPE IN (''N'',''I'')
            UNION
            SELECT DISTINCT ROUTE_NUMBER,
                            TOWN_NAME,
                           '
                || l_column
                || ',
                           '
                || YR
                || '    mtch
              FROM V_COMPLETE_TRANSP_NETWORK
             WHERE snapshot_year = '
                || YR
                || ' AND ROUTE_TYPE IN (''N'', ''I'')
            MINUS
            SELECT DISTINCT ROUTE_NUMBER,
                            TOWN_NAME,
                           '
                || l_column
                || ',
                            '
                || YR
                || '   mtch
              FROM V_COMPLETE_TRANSP_NETWORK
             WHERE snapshot_year = '
                || prev_yr
                || ' AND ROUTE_TYPE IN (''N'', ''I''))';


            LOOP
                FETCH CV
                    INTO l_route_number,
                         l_town,
                         l_col_value,
                         l_yr;

                EXIT WHEN CV%NOTFOUND;

                INSERT INTO changed_attributes (ROUTE_NUMBER,
                                                TOWN_NAME,
                                                CHANGE_COLUMN_NAME,
                                                CHANGE_COLUMN_VALUE,
                                                YR)
                     VALUES (l_route_number,
                             l_town,
                             l_Column,
                             l_col_value,
                             l_yr);
            END LOOP;

            CLOSE CV;

            OPEN CV FOR
                   'SELECT n.snapshot_year,
                   n.route_number,
                   n.town_name,
                   n.'
                || l_column
                || ',
                   n.element_id,
                   n.section_id,
                   n.begin_section_mp,
                   n.end_section_mp
              FROM V_COMPLETE_TRANSP_NETWORK  n
                   JOIN changed_attributes crt
                       ON     n.route_number = crt.route_number
                          AND crt.town_name = n.town_name
                          AND n.'
                || l_column
                || ' = crt.CHANGE_COLUMN_VALUE 
                          AND n.snapshot_year = crt.yr
             WHERE     n.ROUTE_TYPE IN (''N'', ''I'')
                   AND n.primary = ''Y''
                   AND n.snapshot_year IN ('
                || YR
                || ','
                || prev_yr
                || ')';

            LOOP
                FETCH CV
                    INTO l_yr,
                         l_route_number,
                         l_town,
                         l_col_value,
                         l_element_id,
                         l_section_id,
                         l_begin_section_mp,
                         l_end_section_mp;

                EXIT WHEN CV%NOTFOUND;

                INSERT INTO changed_sections (BEGIN_SECTION_MP,
                                              ELEMENT_ID,
                                              END_SECTION_MP,
                                              CHANGE_COLUMN_NAME,
                                              CHANGE_COLUMN_VALUE,
                                              ROUTE_NUMBER,
                                              SECTION_ID,
                                              SNAPSHOT_YEAR,
                                              TOWN_NAME)
                     VALUES (l_BEGIN_SECTION_MP,
                             l_ELEMENT_ID,
                             l_END_SECTION_MP,
                             l_column,
                             l_col_value,
                             l_ROUTE_NUMBER,
                             l_SECTION_ID,
                             l_yr,
                             l_TOWN);
            END LOOP;

            CLOSE CV;


            FOR r IN ranges_dissolved
            LOOP
                INSERT INTO dissolved_ranges (BEGIN_TOWN_MP,
                                              END_TOWN_MP,
                                              CHANGE_COLUMN_NAME,
                                              CHANGE_COLUMN_VALUE,
                                              ROUTE_NUMBER,
                                              SNAPSHOT_YEAR,
                                              TOWN_NAME)
                     VALUES (R.BEGIN_TOWN_MP,
                             R.END_TOWN_MP,
                             l_column,
                             R.change_column_value,
                             R.ROUTE_NUMBER,
                             R.SNAPSHOT_YEAR,
                             R.TOWN_NAME);
            END LOOP;

            OPEN CV FOR
                   'SELECT DISTINCT
                   c.snapshot_year,
                   c.route_number,
                   c.town_name,
                   c.'
                || l_column
                || ',
                   t.CHANGE_COLUMN_VALUE    ,
                   c.element_id,
                   c.section_id,
                   c.begin_section_mp,
                   c.end_section_mp,
                   CASE
                       WHEN t.begin_town_mp > c.begin_section_mp
                       THEN
                           t.begin_town_mp
                       ELSE
                           c.begin_section_mp
                   END               BEGIN_OVERLAP_MP,
                   CASE
                       WHEN t.END_town_mp < c.END_section_mp
                       THEN
                           t.END_town_mp
                       ELSE
                           c.END_section_mp
                   END               END_OVERLAP_MP
              FROM V_COMPLETE_TRANSP_NETWORK  c
                   JOIN dissolved_ranges t
                       ON     c.route_number = t.route_number
                          AND c.town_name = t.town_name
                          AND c.snapshot_year <> t.snapshot_year
             WHERE     c.snapshot_year IN ('
                || yr
                || ','
                || prev_yr
                || ')
                   AND (    t.begin_town_mp < c.end_section_mp
                        AND c.begin_section_mp < t.end_town_mp
                        AND t.CHANGE_COLUMN_VALUE <> c.'
                || l_column
                || ')';

            LOOP
                FETCH CV
                    INTO l_yr,
                         l_route_number,
                         l_town,
                         l_col_value,
                         l_other_col_value,
                         l_ELEMENT_ID,
                         l_section_id,
                         l_BEGIN_SECTION_MP,
                         l_END_SECTION_MP,
                         l_BEGIN_OVERLAP_MP,
                         l_END_OVERLAP_MP;

                EXIT WHEN CV%NOTFOUND;


                INSERT INTO other_yr_sections (begin_overlap_mp,
                                               begin_section_mp,
                                               change_column_name,
                                               change_column_value,
                                               other_yr_change_column_value,
                                               element_id,
                                               end_overlap_mp,
                                               end_section_mp,
                                               route_number,
                                               section_id,
                                               snapshot_year,
                                               other_year,
                                               town_name)
                     VALUES (l_begin_overlap_mp,
                             l_begin_section_mp,
                             l_column,
                             l_col_value,
                             l_other_col_value,
                             l_element_id,
                             l_end_overlap_mp,
                             l_end_section_mp,
                             l_route_number,
                             l_section_id,
                             l_yr,
                             CASE WHEN l_yr = yr THEN prev_yr ELSE yr END,
                             l_town);
            END LOOP;

            CLOSE CV;

            FOR roy IN ranges_other_yr
            LOOP
                INSERT INTO OTHER_YR_RANGES (BEGIN_RANGE_MP,
                                             END_RANGE_MP,
                                             CHANGE_COLUMN_NAME,
                                             CHANGE_COLUMN_VALUE,
                                             ROUTE_NUMBER,
                                             SNAPSHOT_YEAR,
                                             TOWN_NAME)
                     VALUES (ROY.BEGIN_RANGE_MP,
                             ROY.END_RANGE_MP,
                             l_column,
                             ROY.CHANGE_COLUMN_VALUE,
                             ROY.ROUTE_NUMBER,
                             ROY.SNAPSHOT_YEAR,
                             ROY.TOWN_NAME);
            END LOOP;

            FOR fr IN final_result
            LOOP
                SELECT COUNT (*)
                  INTO cntr
                  FROM HIGHWAY_YR_YR_CHANGES    -- does the row already exist?
                 WHERE     BEGIN_OVERLAP_MP = fr.OVERLAP_start_MP
                       AND BEGIN_SECTION_MP = fr.BEGIN_SECTION_MP
                       AND CHANGE_COLUMN_NAME = l_column
                       AND CHANGE_COLUMN_VALUE = fr.change_column_value
                       AND ELEMENT_ID = fr.ELEMENT_ID
                       AND END_OVERLAP_MP = fr.OVERLAP_end_MP
                       AND END_SECTION_MP = fr.END_SECTION_MP
                       AND OTHER_YEAR =
                           CASE
                               WHEN fr.snapshot_year = yr THEN prev_yr
                               ELSE yr
                           END
                       AND OTHER_YR_CHANGE_COLUMN_VALUE =
                           fr.OTHER_YR_CHANGE_COLUMN_VALUE
                       AND ROUTE_NUMBER = fr.ROUTE_NUMBER
                       AND SECTION_ID = fr.SECTION_ID
                       AND SNAPSHOT_YEAR = fr.SNAPSHOT_YEAR
                       AND TOWN_NAME = fr.TOWN_NAME;

                IF cntr = 0
                THEN
                    INSERT INTO HIGHWAY_YR_YR_CHANGES (
                                    BEGIN_OVERLAP_MP,
                                    BEGIN_SECTION_MP,
                                    CHANGE_COLUMN_NAME,
                                    CHANGE_COLUMN_VALUE,
                                    DATE_CREATED,
                                    ELEMENT_ID,
                                    END_OVERLAP_MP,
                                    END_SECTION_MP,
                                    OTHER_YEAR,
                                    OTHER_YR_CHANGE_COLUMN_VALUE,
                                    ROUTE_NUMBER,
                                    SECTION_ID,
                                    SNAPSHOT_YEAR,
                                    TOWN_NAME)
                             VALUES (
                                        fr.OVERLAP_start_MP,
                                        fr.BEGIN_SECTION_MP,
                                        l_column,
                                        fr.change_column_value,
                                        g_start_time,
                                        fr.ELEMENT_ID,
                                        fr.OVERLAP_end_MP,
                                        fr.END_SECTION_MP,
                                        CASE
                                            WHEN fr.snapshot_year = yr
                                            THEN
                                                prev_yr
                                            ELSE
                                                yr
                                        END,
                                        fr.OTHER_YR_CHANGE_COLUMN_VALUE,
                                        fr.ROUTE_NUMBER,
                                        fr.SECTION_ID,
                                        fr.SNAPSHOT_YEAR,
                                        fr.TOWN_NAME);
                              cntr_added := cntr_added + 1;
                END IF;
            END LOOP;

            COMMIT;
        END LOOP;

        SELECT COUNT (*) INTO cntr FROM HIGHWAY_YR_YR_CHANGES;
        
             V_flat_file_counts_txt :=
               'HIGHWAY_YR_YR_CHANGES: '
            || 'Total Rows: '
            || cntr
            || ' Added: '
            || cntr_added
            ;

        WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
            OWNER         => G_OWNER,
            OBJECT_NAME   => g_object,
            object_cnt    => cntr,
            add_cnt       => cntr_added,
            proc          => $$PLSQL_UNIT,
            start_time    => g_start_time);

        wh_common.pkg_common_utilities.EXIT_AND_REPORT (
            $$PLSQL_UNIT,
            'NORMAL',
            V_flat_file_counts_txt);
                   
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
            end;
    END;
/
