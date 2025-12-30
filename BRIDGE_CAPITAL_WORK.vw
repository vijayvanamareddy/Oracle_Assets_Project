CREATE OR REPLACE VIEW WH_ASSETS.BRIDGE_CAPITAL_WORK
BEQUEATH DEFINER
AS 
SELECT B.bridge_ID,
           B.BRIDGE_NAME,
           C.ASSET_NUMBER,
           P.ASSET_TYPE_DESC,
           b.TOWNCODE,
           b.TOWN_NAME1,
           C.PROJECT_BMP,
           M.CONCOMP_ACTUAL,
           M.CONBEGIN_FORECAST,
           M.CONCOMP_ACTUAL,
           M.CONCOMP_FORECAST,
           C.ROUTE_NUMBER,
           P.DESCRIPTION,
           P.DEVELOP_RESP_GRP,
           P.DEVELOP_RESP_DESC,
           P.FEDERAL_PROJECT,
           P.LEAD_UNIT,
           P.PIN,
           P.PROGRAM_MGR,
           P.PMGR_FIRST_LAST,
           P.PROJECT_TITLE,
           P.PROJ_SEQ,
           P.PROJ_STATUS_CODE,
           P.PROJ_STATUS_DESC,
           P.SCOPE_DESC,
           P.SCOPE_GROUP,
           P.WORK_STATUS
      FROM WH_ASSETS.PROJECT_LOCATIONS  C
           JOIN WH_PROJEX.DB_MODEL_PM_PROJECT P ON C.PSN = P.PROJ_SEQ 
           join wh_projex.DB_MODEL_MILESTONES M ON C.PSN = M.PROJ_SEQ
            join ibridges b on b.bridge_number = c.asset_number
     WHERE c.ASSET_TYPE = 'BRIDGE'
     UNION SELECT B.bridge_ID,
           B.BRIDGE_NAME,
           C.ASSET_NUMBER,
           P.ASSET_TYPE_DESC,
           b.TOWNCODE,
           b.TOWN_NAME1,
           C.PROJECT_BMP,
           M.CONCOMP_ACTUAL,
           M.CONBEGIN_FORECAST,
           M.CONCOMP_ACTUAL,
           M.CONCOMP_FORECAST,
           C.ROUTE_NUMBER,
           P.DESCRIPTION,
           P.DEVELOP_RESP_GRP,
           P.DEVELOP_RESP_DESC,
           P.FEDERAL_PROJECT,
           P.LEAD_UNIT,
           P.PIN,
           P.PROGRAM_MGR,
           P.PMGR_FIRST_LAST,
           P.PROJECT_TITLE,
           P.PROJ_SEQ,
           P.PROJ_STATUS_CODE,
           P.PROJ_STATUS_DESC,
           P.SCOPE_DESC,
           P.SCOPE_GROUP,
           P.WORK_STATUS
      FROM WH_ASSETS.PROJECT_LOCATIONS  C
           JOIN WH_PROJEX.DB_MODEL_PM_PROJECT P ON C.PSN = P.PROJ_SEQ 
           join wh_projex.DB_MODEL_MILESTONES M ON C.PSN = M.PROJ_SEQ
            join archived_bridges b on b.bridge_number = c.asset_number
     WHERE c.ASSET_TYPE = 'BRIDGE';
