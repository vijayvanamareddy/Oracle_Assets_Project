CREATE OR REPLACE VIEW WH_ASSETS.V_TIDE_WH_AGENCY_HMVM
BEQUEATH DEFINER
AS 
SELECT FED_URBRUR
                 FEDERAL_URBAN_RURAL_DESCR,
             JRSD_AGENCY
                 AGENCY,
             CASE
                 WHEN JRSD_AGENCY = 'CTY' THEN 'County'
                 WHEN JRSD_AGENCY = 'FEO' THEN 'Federal Other'
                 WHEN JRSD_AGENCY = 'MDOT' THEN 'MDOT'
                 WHEN JRSD_AGENCY = 'MIL' THEN 'Military'
                 WHEN JRSD_AGENCY = 'MTA' THEN 'MTA'
                 WHEN JRSD_AGENCY = 'NFD' THEN 'National Forest Dev'
                 WHEN JRSD_AGENCY = 'NFH' THEN 'National Forest Highway'
                 WHEN JRSD_AGENCY = 'NP' THEN 'National Park'
                 WHEN JRSD_AGENCY = 'OTH' THEN 'Other'
                 WHEN JRSD_AGENCY = 'SF' THEN 'State Forest'
                 WHEN JRSD_AGENCY = 'SP' THEN 'State Park'
                 WHEN JRSD_AGENCY = 'TWN' THEN 'Town'
             END
                 AGENCY_DESCR,
             SUM (HMVM)
                 HMVM,
             TIDEYEAR
                 SNAPSHOT_YEAR
        FROM SEG_HIST@TIDE
       WHERE     TIDEYEAR BETWEEN 2010 AND 2014
             AND JURISCD NOT IN (0)
             AND HMVM <> 0
    GROUP BY FED_URBRUR, TIDEYEAR, JRSD_AGENCY
    UNION
      SELECT FEDERAL_URBAN_RURAL_DESCR,
             AGENCY,
             AGENCY_DESCR,
             SUM (HUNDRED_MILLION_VEHICLE_MILES) HMVM,
             SNAPSHOT_YEAR
        FROM  COMPLETE_TRANSPORTATION_NETWORK 
     WHERE route_type IN ('I', 'N') AND primary = 'Y'
       AND     SNAPSHOT_YEAR BETWEEN 2015 AND 2020
             AND HUNDRED_MILLION_VEHICLE_MILES > 0
    GROUP BY FEDERAL_URBAN_RURAL_DESCR,
             AGENCY,
             AGENCY_DESCR,
             SNAPSHOT_YEAR
    ORDER BY SNAPSHOT_YEAR, FEDERAL_URBAN_RURAL_DESCR, AGENCY;
