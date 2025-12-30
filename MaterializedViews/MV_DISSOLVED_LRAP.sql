CREATE MATERIALIZED VIEW MV_DISSOLVED_LRAP
NOCACHE
NOLOGGING
NOCOMPRESS
NOPARALLEL
NO INMEMORY
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
WITH PRIMARY KEY
AS 
SELECT d.snapshot_year,
         d.route_number,
         begin_mp,
         end_mp,
         d.town_name,
         d.streetname,
         d.begin_node_id,
         d.begin_node_description,
         d.end_node_id,
         d.end_node_description,
         d.jurisdiction,
         d.state_urban_rural_descr,
         d.federal_functional_class,
         d.maint_resp_winter_descr,
         d.maint_resp_year_descr,
         d.jurisdiction_code,
         d.wcsh_code,
         d.plow_crew,
         d.town_code,
         d.state_urban_rural,
         d.geographic_area_type,
         d.county_code,
         d.county_name,
         d.LRAP_Category,
         SUM (
             CASE
                 WHEN number_of_lanes <= 2
                 THEN
                     (section_length * number_of_lanes)
                 ELSE
                     (section_length * 2)
             END)    AS first2_lane_miles,
         SUM (
             CASE
                 WHEN number_of_lanes > 2
                 THEN
                     (section_length * (number_of_lanes - 2))
                 ELSE
                     0
             END)    AS over2_lane_miles,
         CASE
             WHEN d.lrap_category = '1 USH'
             THEN
                     SUM (
                         CASE
                             WHEN number_of_lanes <= 2
                             THEN
                                 (section_length * number_of_lanes)
                             ELSE
                                 (section_length * 2)
                         END)                            -- first2_lane_miles,
                   * 4200
                 +   SUM (
                         CASE
                             WHEN number_of_lanes > 2
                             THEN
                                 (section_length * (number_of_lanes - 2))
                             ELSE
                                 0
                         END)
                   * 2950.00                              -- over 2 lane miles
             WHEN d.lrap_category = '2 USA'
             THEN
                     SUM (
                         CASE
                             WHEN number_of_lanes <= 2
                             THEN
                                 (section_length * number_of_lanes)
                             ELSE
                                 (section_length * 2)
                         END)                            -- first2_lane_miles,
                   * 2500.00
                 +   SUM (
                         CASE
                             WHEN number_of_lanes > 2
                             THEN
                                 (section_length * (number_of_lanes - 2))
                             ELSE
                                 0
                         END)
                   * 1250.00                              -- over 2 lane miles
             WHEN d.lrap_category = '3 WCSH'
             THEN
                     SUM (
                         CASE
                             WHEN number_of_lanes <= 2
                             THEN
                                 (section_length * number_of_lanes)
                             ELSE
                                 (section_length * 2)
                         END)
                   * 1700.00                             -- first2_lane_miles,
                 +   SUM (
                         CASE
                             WHEN number_of_lanes > 2
                             THEN
                                 (section_length * (number_of_lanes - 2))
                             ELSE
                                 0
                         END)
                   * 1700.00                              -- over 2 lane miles
             WHEN d.lrap_category IN ('4 RSA', '5 TW')
             THEN
                     SUM (
                         CASE
                             WHEN number_of_lanes <= 2
                             THEN
                                 (section_length * number_of_lanes)
                             ELSE
                                 (section_length * 2)
                         END)
                   * 600.00                              -- first2_lane_miles,
                 +   SUM (
                         CASE
                             WHEN number_of_lanes > 2
                             THEN
                                 (section_length * (number_of_lanes - 2))
                             ELSE
                                 0
                         END)
                   * 600.00                               -- over 2 lane miles
             WHEN d.lrap_category = '6 STW'
             THEN
                     SUM (
                         CASE
                             WHEN number_of_lanes <= 2
                             THEN
                                 (section_length * number_of_lanes)
                             ELSE
                                 (section_length * 2)
                         END)
                   * 300.00                              -- first2_lane_miles,
                 +   SUM (
                         CASE
                             WHEN number_of_lanes > 2
                             THEN
                                 (section_length * (number_of_lanes - 2))
                             ELSE
                                 0
                         END)
                   * 300.00                               -- over 2 lane miles
             ELSE
                 0
         END         lrap_extract
    FROM v_complete_transp_network c
         JOIN v_dissolved_lrap d
             ON     c.route_number = d.route_number
                AND c.town_name = d.town_name
                AND (    d.begin_mp < c.end_section_mp
                     AND c.begin_section_mp < d.end_mp)
   WHERE c.SNAPSHOT_YEAR = d.snapshot_year
GROUP BY d.snapshot_year,
         d.route_number,
         d.town_name,
         d.streetname,
         d.FEDERAL_FUNCTIONAL_CLASS,
         d.jurisdiction,
         d.jurisdiction_code,
         d.state_urban_rural_descr,
         d.maint_resp_winter_descr,
         d.maint_resp_year_descr,
         d.wcsh_code,
         d.plow_crew,
         d.town_code,
         d.state_urban_rural,
         d.geographic_area_type,
         d.county_code,
         d.county_name,
         d.lrap_category,
         d.begin_node_id,
         d.begin_node_description,
         d.end_node_id,
         d.end_node_description,
         begin_mp,
         end_mp;
