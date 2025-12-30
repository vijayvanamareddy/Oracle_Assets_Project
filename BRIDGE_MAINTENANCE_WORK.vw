CREATE OR REPLACE VIEW WH_ASSETS.BRIDGE_MAINTENANCE_WORK
BEQUEATH DEFINER
AS 
SELECT BRIDGE_ID,
           ASSET_NAME,
           ASSET_NUMBER,
           ACTIVITY,
           A.DESCR,
           W.DWR_SYS_ID,
           W.DWR_DATE,
           BEGIN_WORK_MP,
           ROUTE_NUMBER,
           OUC,
           F.WIN,
           WORK_REQUEST_ID,
           wr.DESCR,
           f.ACCOMP_QTY,
           a.accomp_uom_id
      FROM maint_WORK_locations w join wh_mats.DIM_DWR_ACTIVITY a on a.DISPLAY_CODE = w.ACTIVITY JOIN wh_mats.fact_dwr f ON w.DWR_SYS_ID = f.DWR_SYS_ID join wh_mats.DIM_WORK_REQUESTS wr on
      wr.TXN_WR_SYS_ID = f.TXN_WR_SYS_ID LEFT OUTER JOIN IBRIDGES b on b.bridge_number = w.asset_number
     WHERE w.ASSET_TYPE = 'Bridge';
