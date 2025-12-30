CREATE OR REPLACE VIEW WH_ASSETS.ELEMENTS
BEQUEATH DEFINER
AS 
SELECT BEGIN_NODE_DESCRIPTION,
           BEGIN_NODE_ID,
           COUNTY_CODE,
           COUNTY_NAME,
           DIRECTIONAL_SUFFIX,
           ELEMENT_ID,
           ELEMENT_LENGTH,
           END_NODE_DESCRIPTION,
           END_NODE_ID,
           EXISTING,
           FACTOR_GROUP,
           GA_TYPE,
           GA_TYPE_DESCR,
           ELEMENT_WID,
           NUMBER_OF_LANE_XSECTIONS,
           OFFICIAL_MILES,
           ONE_WAY,
           ONE_WAY_DESCR,
           PRIMARY_ROUTE_NAME,
           PRIMARY_ROUTE_NUMBER,
           RAMP,
           RAMP_DESCR,
           REGION,
           REGION_DESCR,
           ROUTE_GROUP,
           ROUTE_SYSTEM,
           ROUTE_TYPE,
           TOWN,
           TOWN_CODE
      FROM ELEMENT_HISTORY
     WHERE END_DATE IS NULL;
