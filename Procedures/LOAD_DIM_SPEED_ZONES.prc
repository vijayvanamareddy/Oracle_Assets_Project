CREATE OR REPLACE PROCEDURE load_dim_speed_zones
IS
    /**********************************************************************
    This procedure loads the dim_speed_zones_table,
    It is run after loading the speed_zones table

    It truncates the table and re-loads it weekly

    04-18-19 SH  Initial Version, based on view created by C. Owings
    10-01-19 SH  Add route in subqueries of cursor to fix bug where wrong end point returned reported by T. Marcotte
    04-02-20 SH  Replace sequence number in cursor query with begin/end mp to fix problem with duplicate inventory route records
                 Note:  end_node and end_offset  indicate if the offset is from the start or end node.  
                 If the end_offset is zero its from the end node.  If the end_offset is non-zero, the end_offset is from the start node.
    09-16-20 SH Fix bug where a speed zone does not end on a node boundary, the end milepoint (end_mp) was the end milepoint of the element
                Change the end milepoint to be the end milepoint where the speed zone actually ends within the element
                Since we don't want to change obiee, change column name end_mp to end_element_mp
                Change virtual column name emp to end_mp 
   01-27-2023 SH Include town and street_name in groupings DOTDW-763
   03-14-2023 SH Replace min/max portion of code (sz1) with dissolve to handle speed zone 2649941 
    **********************************************************************/


    commit_count   NUMBER (7) := 0;
    cntr           NUMBER (7) := 0;

    g_start_time   DATE := SYSDATE;
    g_owner        VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname      VARCHAR2 (30) := 'LOAD_DIM_SPEED_ZONES';
    g_object       VARCHAR2 (20) := 'DIM_SPEED_ZONES';
    g_sqlmsg       VARCHAR2 (500) := NULL;

    errlog_count      NUMBER;
    err_log_message   VARCHAR2 (200);

    CURSOR spz
    IS
    SELECT SZ1.SPEED_ZONE_ID,
               b.town,
               REGION,
               asset_descr AS ROUTE,
               SZ1.STREET_NAME,
               STREET_PREFIX,
               STREET_TYPE,
               sz1.RTE_NAME,
               sz_group,
               SZ_DESCR,
               b.speed,
               SZ_UPDATED_BY,
               SZ_LAST_UPDATE,
               SZ_EFFECTIVE_DATE,
               RT_UPDATED_BY,
               RT_LAST_UPDATE,
               b.start_node,
               b.start_descr,
               b.LENGTH,
               b.start_offset,
               b.beg_mp,
               c.end_node,
               c.end_descr,
               c.end_offset,
               c.end_mp
          FROM (  SELECT 
       SPEED_ZONE_ID,
       rte_name,
       town,
       street_name,
       MIN (bmp) min_mp,
       MAX (end_mp) max_mp
  FROM (  SELECT SPEED_ZONE_ID,
                 rte_name,
                 town,
                 street_name,
                 bmp,
                 end_mp,
                 DENSE_RANK ()
                     OVER (PARTITION BY SPEED_ZONE_ID,
                                        rte_name,
                                        town,
                                        street_name
                           ORDER BY
                               SPEED_ZONE_ID,
                               rte_name,
                               town,
                               street_name,
                               bmp)    AS DS_rn
            FROM speed_zones ORDER BY speed_zone_id, rte_name, bmp)
                     MATCH_RECOGNIZE (
                         ORDER BY
                             rte_name,
                             town,
                             street_name,
                             bmp,
                             ds_rn
                         MEASURES classifier () AS var, match_number () AS grp
                         ALL ROWS PER MATCH
                         PATTERN (strt consecutive *)
                         DEFINE
                             consecutive AS     bmp = (prev (end_mp))
                                            AND ds_rn = (prev (ds_rn) + 1))
        GROUP BY grp,
                 SPEED_ZONE_ID,
                 rte_name,
                 town,
                 street_name
        ) SZ1,
               (SELECT speed_zone_id,
                       town,
                       REGION,
                       asset_descr,
                       STREET_NAME,
                       STREET_PREFIX,
                       STREET_TYPE,
                       RTE_NAME,
                       sz_group,
                       SZ_DESCR,
                       SZ_UPDATED_BY,
                       SZ_LAST_UPDATE,
                       SZ_EFFECTIVE_DATE,
                       RT_UPDATED_BY,
                       RT_LAST_UPDATE,
                       start_node,
                       start_descr,
                       seq_no,
                       LENGTH,
                       start_offset,
                       end_offset,
                       speed,
                       end_element_mp,
                       bmp,
                       end_element_mp - LENGTH + start_offset AS beg_mp
                  FROM SPEED_ZONES) b,
               (SELECT speed_zone_id,
                       rte_name,
                       town,
                       street_name,
                       CASE
                           WHEN end_offset = 0 THEN end_node 
                           ELSE start_node
                       END
                           end_node,
                       CASE
                           WHEN end_offset = 0 THEN end_descr
                           ELSE start_descr
                       END
                           end_descr,
                       seq_no,
                       end_mp,
                       end_offset
                  FROM SPEED_ZONES) c
         WHERE     sz1.speed_zone_id = b.speed_zone_id
               AND sz1.speed_zone_id = c.speed_zone_id
               AND b.bmp = sz1.min_mp  -- get row with lowest mp in speed zone
               AND c.end_mp = sz1.max_mp -- get row with highest mp in speed zone
               AND sz1.rte_name = b.rte_name
               AND sz1.rte_name = c.rte_name
               AND sz1.town = b.town
               AND sz1.town = c.town
               AND (SZ1.STREET_NAME = b.STREET_NAME or sz1.street_name is null)   
               AND (SZ1.STREET_NAME = c.STREET_NAME or sz1.street_name is null)             
              ;
   
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE DIM_SPEED_ZONES';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE DIM_SPEED_ZONES_ERROR_LOG';

    FOR s IN spz
    LOOP
        INSERT INTO DIM_SPEED_ZONES (BEG_MP,
                                     END_DESCR,
                                     END_MP,
                                     END_NODE,
                                     END_OFFSET,
                                     LENGTH,
                                     REGION,
                                     ROUTE,
                                     RTE_NAME,
                                     RT_LAST_UPDATE,
                                     RT_UPDATED_BY,
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
             VALUES (S.BEG_MP,
                     S.END_DESCR,
                     S.END_MP,
                     S.END_NODE,
                     S.END_OFFSET,
                     S.LENGTH,
                     S.REGION,
                     S.ROUTE,
                     S.RTE_NAME,
                     S.RT_LAST_UPDATE,
                     S.RT_UPDATED_BY,
                     S.SPEED,
                     S.SPEED_ZONE_ID,
                     S.START_DESCR,
                     S.START_NODE,
                     S.START_OFFSET,
                     S.STREET_NAME,
                     S.STREET_PREFIX,
                     S.STREET_TYPE,
                     S.SZ_DESCR,
                     S.SZ_EFFECTIVE_DATE,
                     S.SZ_GROUP,
                     S.SZ_LAST_UPDATE,
                     S.SZ_UPDATED_BY,
                     S.TOWN)
                LOG ERRORS INTO DIM_SPEED_ZONES_ERROR_LOG
                        ('LOAD_DIM_SPEED_ZONES ' || SYSDATE)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;
  
 -- Check  error log for quality errors

    SELECT COUNT (*) INTO errlog_count FROM wh_assets.DIM_SPEED_ZONES_ERROR_LOG;

    IF errlog_count > 0
    THEN
        BEGIN
            err_log_message :=
                'Unexpected Data Quality Issues in DIM_SPEED_ZONES_ERROR_LOG';

            INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                            ERR_MODULE,
                                            ERR_OID,
                                            ERR_MESSAGE)
                 VALUES (SYSDATE,
                         'LOAD_DIM_SPEED_ZONES',
                         'WH_ASSETS',
                         err_log_message);

            INSERT INTO data_exceptions (TABLE_NAME,
                                         ERROR_CONDITION,
                                         TEST_PROCEDURE,
                                         TEST_DATE,
                                         ASSESSMENT)
                 VALUES ('DIM_SPEED_ZONES_ERROR_LOG',
                         'Invalid data - check error log',
                         g_jobname,
                         g_start_time,
                         'QUALITY');

            COMMIT;
        END;
    END IF;


    SELECT COUNT (*) INTO cntr FROM DIM_SPEED_ZONES;

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
