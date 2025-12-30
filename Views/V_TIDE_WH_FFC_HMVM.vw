CREATE OR REPLACE VIEW WH_ASSETS.V_TIDE_WH_FFC_HMVM
BEQUEATH DEFINER
AS 
SELECT FED_URBRUR
                 FEDERAL_URBAN_RURAL_DESCR,
             CASE
                 WHEN FEDFUNCLCD = 1 THEN 'Interstate'
                 WHEN FEDFUNCLCD = 2 THEN 'Other Freeway or Expressway'
                 WHEN FEDFUNCLCD = 3 THEN 'Other Principal Arterial'
                 WHEN FEDFUNCLCD = 4 THEN 'Minor Arterial'
                 WHEN FEDFUNCLCD = 5 THEN 'Major Collector'
                 WHEN FEDFUNCLCD = 6 THEN 'Minor Collector'
                 WHEN FEDFUNCLCD = 0 THEN 'Local'
             END
                 FFC,
             SUM (HMVM)
                 HMVM,
             TIDEYEAR
                 SNAPSHOT_YEAR
        FROM SEG_HIST@TIDE
       WHERE     TIDEYEAR BETWEEN 2010 AND 2014
             AND JURISCD NOT IN (0)
             AND HMVM <> 0
    GROUP BY FED_URBRUR, TIDEYEAR, FEDFUNCLCD
    UNION
      SELECT FEDERAL_URBAN_RURAL_DESCR,
             FEDERAL_FUNCTIONAL_CLASS_DESCR    FFC,
             SUM (HUNDRED_MILLION_VEHICLE_MILES) HMVM,
             SNAPSHOT_YEAR
        FROM COMPLETE_TRANSPORTATION_NETWORK
       WHERE   route_type IN ('I', 'N') AND primary = 'Y' AND 
             SNAPSHOT_YEAR BETWEEN 2015 AND 2020
             AND HUNDRED_MILLION_VEHICLE_MILES > 0
             AND FEDERAL_FUNCTIONAL_CLASS_DESCR IS NOT NULL
    GROUP BY FEDERAL_URBAN_RURAL_DESCR,
             FEDERAL_FUNCTIONAL_CLASS_DESCR,
             SNAPSHOT_YEAR
    ORDER BY SNAPSHOT_YEAR, FEDERAL_URBAN_RURAL_DESCR, FFC;
