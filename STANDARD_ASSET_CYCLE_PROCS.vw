CREATE OR REPLACE VIEW WH_ASSETS.STANDARD_ASSET_CYCLE_PROCS
BEQUEATH DEFINER
AS 
SELECT distinct wlog_procedure
     FROM wh_common.tb_whse_log where wlog_owner = 'WH_ASSETS' and wlog_procedure is not null;
