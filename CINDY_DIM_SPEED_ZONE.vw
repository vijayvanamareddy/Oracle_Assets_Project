CREATE OR REPLACE VIEW WH_ASSETS.CINDY_DIM_SPEED_ZONE
BEQUEATH DEFINER
AS 
SELECT  SZ1.SPEED_ZONE_ID, town, REGION, asset_descr as ROUTE, STREET_NAME, STREET_PREFIX, STREET_TYPE, RTE_NAME, sz_group, SZ_DESCR, b.speed,SZ_UPDATED_BY, SZ_LAST_UPDATE, SZ_EFFECTIVE_DATE, 
   RT_UPDATED_BY, RT_LAST_UPDATE, b.start_node, b.start_descr, b.length, b.start_offset, b.beg_mp, c.end_node, c.end_descr, c.end_offset, c.end_mp FROM (
select a.SPEED_ZONE_ID,  min(seq_no) as min_seq, max(seq_no) as max_seq
from
CINDY_TEST_SPEED_ZONE a group by speed_zone_id) SZ1,
(select speed_zone_id, town, REGION, asset_descr ,STREET_NAME, STREET_PREFIX, STREET_TYPE, RTE_NAME, sz_group, SZ_DESCR, SZ_UPDATED_BY, SZ_LAST_UPDATE, SZ_EFFECTIVE_DATE, 
   RT_UPDATED_BY, RT_LAST_UPDATE, start_node, start_descr, seq_no, length, start_offset, end_offset, speed, end_mp, end_mp-length + start_offset as beg_mp from
cindy_test_speed_zone) b,
 (select speed_zone_id, case when end_offset = 0 then end_node else start_node end end_node, case when end_offset = 0 then end_descr else start_descr end end_descr, seq_no, end_offset, case when end_offset <> 0 then end_mp - length + end_offset else end_mp end end_mp from
cindy_test_speed_zone) c
where sz1.speed_zone_id = b.speed_zone_id and b.seq_no = sz1.min_seq
and
sz1.speed_zone_id = c.speed_zone_id and c.seq_no = sz1.max_seq
--and sz1.speed_zone_id in (1947831)
;
