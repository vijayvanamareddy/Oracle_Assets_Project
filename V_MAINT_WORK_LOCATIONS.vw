CREATE OR REPLACE VIEW WH_ASSETS.V_MAINT_WORK_LOCATIONS
BEQUEATH DEFINER
AS 
SELECT MWP.ACTIVITY,
           A.DESCR,
           WR.ACTIVITY_SCOPE,
           MWP.ASSET_NAME,
           MWP.ASSET_NUMBER,
           MWP.ASSET_TYPE,
           MWP.BEGIN_WORK_MP,
           MWP.END_WORK_MP,
           MWP.DWR_DATE,
           MWP.DWR_SYS_ID,
           MWP.ELEMENT_ID,
           MWP.ROUTE_DIRECTION,
           MWP.ROUTE_NUMBER,
           MWP.SECTION_BMP,
           MWP.SECTION_EMP,
           MWP.SECTION_ID,
           MWP.TOWN,
           MWP.WORK_REQUEST_ID,
           F.ACCIDENT_YES_NO,
           A.ACCOMP_UOM_ID,
           F.OUC
      FROM MAINT_WORK_LOCATIONS  MWP
           LEFT OUTER JOIN WH_MATS.FACT_DWR F
               ON MWP.DWR_SYS_ID = F.DWR_SYS_ID
           LEFT OUTER JOIN WH_MATS.DIM_DWR_ACTIVITY A
               ON A.DISPLAY_CODE = MWP.ACTIVITY
           LEFT OUTER JOIN WH_MATS.DIM_WORK_REQUESTS WR
               ON     WR.TXN_WR_SYS_ID = MWP.WORK_REQUEST_ID
                  AND (   activity_scope = 'Surface and Base Maintenance'
                       OR (   asset_type = 'Bridge'
                           OR asset_type = 'Large Culvert'));
