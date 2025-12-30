CREATE OR REPLACE VIEW WH_ASSETS.CINDY_VR_TOWN1_REPORT
BEQUEATH DEFINER
AS 
SELECT a.COUNTY_CODE,
             a.TOWN_CODE,
             a.JURISDICTION_CODE,
             a.ROUTE_NUMBER,
             a.JURISDICTION_ABBREVIATION,
             0.00
                 breakpoint,
             a.SECTION_ID,
             a.ELEMENT_ID,
             a.ELEMENT_LENGTH,
             --DECODE (prirtedir, 1, b.lnode, hnode)                  low_node,
             --DECODE (prirtedir, 1, b.hnode, lnode)                  high_node,
             --DECODE (prirtedir, 1, a.boffset, b.lenlnk - a.eoffset) boffset,
             --DECODE (prirtedir, 1, a.eoffset, b.lenlnk - a.boffset) eoffset,
             CASE
                 WHEN a.direction = 1 THEN ROUND (a.begin_offset, 2)
                 ELSE ROUND (a.element_length - a.end_offset, 2)
             END
                 AS begin_offset,
             CASE
                 WHEN a.direction = 1 THEN ROUND (a.end_offset, 2)
                 ELSE ROUND (a.element_length - a.begin_offset, 2)
             END
                 AS end_offset,
             --round(a.BEGIN_OFFSET,2),
             --round(a.END_OFFSET,2),
             ROUND (a.SECTION_LENGTH, 2),
             a.TOWN,
             ROUND (a.BEGIN_SECTION_MP, 2),
             ROUND (a.END_SECTION_MP, 2),
             --a.element_length -round(A.END_ELEMENT_MILEPOINT,2) testboffset,
             --a.element_length - round(A.BEGIN_ELEMENT_MILEPOINT,2) testeoffset,
             a.STREET_NAME || ' ' || A.STREET_NAME_SUFFIX,
             a.BEGIN_NODE_ID,
             a.END_NODE_ID,
             a.BEGIN_NODE_DESCRIPTION
                 Low_descr,
             A.END_NODE_DESCRIPTION
                 high_descr,
             A.STATE_URBAN_RURAL_DESCR,
             CASE A.WCSH_CODE
                 WHEN 'N' THEN '0'
                 WHEN 'Y' THEN '1'
                 WHEN 'A' THEN A.WCSH_AGREEMENT
             END
                 WCSH_CODE,
             a.FEDERAL_FUNCTIONAL_CLASS,
             000.00
                 AS segsum,
             000.00
                 AS low_node_offset,
             000.00
                 AS high_node_offset
        FROM route_sections A
       WHERE                   --town in ('Durham','Rockland','Kittery')-- and
                                          --ROUTE_NUMBER in ('0001A', '0009X')
                                                                         --AND
                 A.ROUTE_TYPE IN ('N', 'I')
             AND A.OFFICIAL_MILES = 'Y'
             AND A.ramp = 0
             AND A.JURISDICTION_ABBREVIATION <> 'RESV'
             AND A.JURISDICTION_ABBREVIATION <> 'TOLL'
    ORDER BY A.BEGIN_section_mp;
