CREATE OR REPLACE VIEW WH_ASSETS.V_CSL_BRIDGE_INFO
BEQUEATH DEFINER
AS 
WITH
        bridgeinfo
        AS
            (SELECT bridge_number
                        AS brdgno,
                    type_of_service_on
                        AS type_service_on_code,
                    type_of_service_under
                        AS type_service_under_code,
                    bridge_length
                        AS LENGTH,
                    deck_area,
                    approach_span_number
                        AS NUMBER_OF_APPROACH_SPANS,
                    main_span_number
                        AS number_of_main_spans,
                    length_max_span
                        AS max_span,
                    bridge_indicator
                        AS s630,
                    maintenance_region || ' ' || maintenance_region_descr
                        AS region,
                    owner_descr
                        AS owner,
                    maintainer_descr
                        AS custodian,
                    owner
                        AS owner_code,
                    maintainer
                        AS maintainer_code,
                    bridge_group,
                    LTRIM (type_of_service_on_descr, '0123456789 - ')
                        AS TYPE_SERVICE_ON,
                    LTRIM (type_of_service_under_descr, '0123456789 - ')
                        AS TYPE_SERVICE_UNDER,
                    NVL (vehicle_load_limit, 0)
                        AS u_vhldlim,
                    NVL (posted_weight_tons, 0)
                        AS u_tkldlim,
                    posted
                        AS posted,
                    posted_1_truck
                        AS posted_1_truck,
                    posted_spacing
                        AS posted_spacing,
                    CASE
                        WHEN structure_open = 'K'
                        THEN
                            'Closed'
                        WHEN upper(posted) = 'YES' AND posted_weight_tons > 0
                        THEN
                            'Posted'
                        WHEN    upper(posted_1_truck) = 'YES'
                             OR UPPER(posted_spacing) = 'YES'
                        THEN
                            'Posted'
                        ELSE
                            'N/A'
                    END
                        AS BRDPSTING,
                    CASE
                        WHEN structure_open = 'K'
                        THEN
                            'N/A'
                        WHEN upper(posted) = 'YES' AND posted_weight_tons >= 0
                        THEN
                            'Load Posting'
                        WHEN    UPPER(posted_1_truck) = 'YES'
                             OR upper(posted_spacing) = 'YES'
                        THEN
                            '1 Truck or Spacing'
                        ELSE
                            'N/A'
                    END
                        AS PSTTYPE,
                    CAST (
                        CASE
                            WHEN deck_rating = 'N'
                            THEN
                                999
                            WHEN deck_rating = '_'
                            THEN
                                999
                            WHEN deck_rating >= 0 AND deck_rating <= 10
                            THEN
                                CAST (deck_rating AS NUMBER (3))
                            ELSE
                                999
                        END
                            AS NUMBER (3))
                        AS dck_cndtn,
                    CAST (
                        CASE
                            WHEN superstructure_rating = 'N'
                            THEN
                                999
                            WHEN superstructure_rating = '_'
                            THEN
                                999
                            WHEN     superstructure_rating >= 0
                                 AND superstructure_rating <= 10
                            THEN
                                CAST (superstructure_rating AS NUMBER (3))
                            ELSE
                                999
                        END
                            AS NUMBER (3))
                        AS sprstr_cnd,
                    CAST (
                        CASE
                            WHEN substructure_rating = 'N'
                            THEN
                                999
                            WHEN substructure_rating = '_'
                            THEN
                                999
                            WHEN     substructure_rating >= 0
                                 AND substructure_rating <= 10
                            THEN
                                CAST (substructure_rating AS NUMBER (3))
                            ELSE
                                999
                        END
                            AS NUMBER (3))
                        AS substr_cnd,
                    CAST (
                        CASE
                            WHEN culvert_rating = 'N'
                            THEN
                                999
                            WHEN culvert_rating = '_'
                            THEN
                                999
                            WHEN culvert_rating >= 0 AND culvert_rating <= 10
                            THEN
                                CAST (culvert_rating AS NUMBER (3))
                            ELSE
                                999
                        END
                            AS NUMBER (3))
                        AS clvrt_cnd,
                    CAST (
                        CASE
                            WHEN scour_rating = 'N'
                            THEN
                                999
                            WHEN scour_rating = '_'
                            THEN
                                999
                            WHEN scour_rating = 'U'
                            THEN
                                3
                            WHEN scour_rating = 'T'
                            THEN
                                999
                            WHEN scour_rating = '!'
                            THEN
                                999
                            WHEN scour_rating = '@'
                            THEN
                                999
                            WHEN scour_rating IS NULL
                            THEN
                                999
                            WHEN scour_rating >= 0 AND scour_rating <= 10
                            THEN
                                CAST (scour_rating AS NUMBER (9, 0))
                            ELSE
                                999
                        END
                            AS NUMBER (3))
                        AS scour,
                    inspection_date
                        AS inspdate,
                    element_id_on_structure
                        AS link_id,
                    offset
                        AS offset,
                    NVL (priority, 6)
                        AS priority
               FROM ibridges),
        bridgelocation
        AS
            (SELECT bridge_number, primary, Location AS location_type
               FROM bridges_on_route
              WHERE location IN ('ON', 'A') AND primary = 'Y')
      SELECT DISTINCT brdgno,
                      type_service_on_code,
                      type_service_under_code,
                      LENGTH,
                      deck_area,
                      number_of_approach_spans,
                      number_of_main_spans,
                      max_span,
                      s630,
                      region,
                      owner,
                      custodian,
                      owner_code,
                      maintainer_code,
                      bridge_group,
                      type_service_on,
                      type_service_under,
                      u_vhldlim,
                      u_tkldlim,
                      posted,
                      posted_1_truck,
                      posted_spacing,
                      brdpsting,
                      psttype,
                      CAST (dck_cndtn AS NUMBER (3))            AS dck_cndtn,
                      CAST (sprstr_cnd AS NUMBER (3))           AS sprstr_cnd,
                      CAST (substr_cnd AS NUMBER (3))           AS substr_cnd,
                      CAST (clvrt_cnd AS NUMBER (3))            AS clvrt_cnd,
                      scour,
                      inspdate,
                      link_id,
                      offset,
                      CASE
                          WHEN bridgelocation.location_type = 'ON' THEN 'B'
                          WHEN bridgelocation.location_type = 'A' THEN 'A'
                      END                                       AS location_type,
                      priority,
                      CAST (LEAST (dck_cndtn,
                                   sprstr_cnd,
                                   substr_cnd,
                                   clvrt_cnd) AS NUMBER (3))    AS strctbrdgcnd
        FROM bridgeinfo
             LEFT OUTER JOIN bridgelocation
                 ON bridgeinfo.Brdgno = bridgelocation.bridge_number
       WHERE     type_service_on NOT IN ('Other')
             AND s630 NOT IN ('S630-0', 'S630 - 0')
             AND link_id IS NOT NULL
             AND bridgelocation.location_type IN ('A', 'ON')
             --and bridge_number = '2478'
    ORDER BY bridgeinfo.brdgno;
