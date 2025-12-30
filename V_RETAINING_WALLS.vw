CREATE OR REPLACE VIEW WH_ASSETS.V_RETAINING_WALLS
BEQUEATH DEFINER
AS 
SELECT 
  "WALL_ID" as wall_id,
  CAST("WALL_NAME" AS varchar2(20)) as wall_name,
  CAST("YEAR_BUILT" AS varchar2(10)) as year_built,
  CAST("INSPECTION_FREQUENCY_YRS" AS int) as inspect_freq,
  CAST("MAINTENANCE_REGION" AS varchar2(4)) as maint_region,
  CAST("MAINTAINER" AS varchar2(4)) as maintainer,
  CAST("WALL_TYPE" AS varchar2(4)) as wall_type,
  CASE
      WHEN REGEXP_LIKE (hcp, '^-?[[:digit:],.]*$')
      THEN
          CAST (hcp AS NUMBER)
      ELSE
          NULL
      END
          AS hcp,
  substr("OWNER", 1, 4) as owner,
  CASE
           WHEN REGEXP_LIKE (FRONT_SLOPE, '^-?[[:digit:],.]*$')
           THEN
               CAST ("FRONT_SLOPE" AS NUMBER)
           ELSE
               NULL
       END
           AS front_slope,
   CASE
           WHEN REGEXP_LIKE (BACK_SLOPE, '^-?[[:digit:],.]*$')
           THEN
               CAST ("BACK_SLOPE" AS NUMBER)
           ELSE
               NULL
       END
           AS back_slope,
  CASE
           WHEN REGEXP_LIKE (HORIZONTAL_OFFSET, '^-?[[:digit:],.]*$')
           THEN
               CAST ("HORIZONTAL_OFFSET" AS NUMBER)
           ELSE
               NULL
       END
           AS horiz_offset,
  CAST("VERTICAL_OFFSET" AS NUMBER) as vert_offset,
  CAST("FACE_ANGLE" AS NUMBER) as face_angle,
  CAST("FACE_AREA" AS NUMBER) as face_area,
  CASE
      WHEN REGEXP_LIKE (towncode, '^-?[[:digit:],.]*$')
      THEN
          CAST (towncode AS varchar2(10))
      ELSE
          NULL
      END
          AS towncode,
  substr("SIDE_OF_CL", 1, 10) as side_of_cl,
  substr("ROUTE_NUMBER", 1, 10) as route_number,
  CASE
    WHEN length(TO_CHAR(last_inspection_date)) <=2
    THEN 
        NULL
    ELSE
        TO_DATE(last_inspection_date, 'fxMM/DD/YYYY')
    END
        AS last_inspection_date,
  CASE
      WHEN REGEXP_LIKE (longitude, '[-+]?[0-9]*\.[0-9]*')
      THEN
          CAST (longitude AS number(7,5))
      ELSE
          NULL
      END
          AS longitude,
  CASE
      WHEN REGEXP_LIKE (latitude,'[-+]?[0-9]*\.[0-9]*')
      THEN
          CAST (latitude AS number(7,5))
      ELSE
          NULL
      END
          AS latitude,
   CASE
      WHEN REGEXP_LIKE (stability_rating, '^-?[[:digit:],.]*$')
      THEN
          CAST (stability_rating AS number)
      ELSE
          NULL
      END
          AS stability_rating,
  CASE
      WHEN REGEXP_LIKE (condition_rating, '^-?[[:digit:],.]*$')
      THEN
          CAST (condition_rating AS number)
      ELSE
          NULL
      END
          AS condition_rating,
  CASE
      WHEN length(TO_CHAR(next_inspection_due)) <=9
      THEN
          NULL
      ELSE
          TO_DATE(next_inspection_due, 'MM/DD/YYYY')
      END
          AS next_inspection_due,
  CASE
      WHEN REGEXP_LIKE (construction_type, '^-?[[:alpha:],.]*$')
      THEN
          CAST (construction_type AS varchar2(30))
      ELSE
          NULL
      END
          AS construction_type, 
  CASE
      WHEN REGEXP_LIKE (facing, '^-?[[:alpha:],.]*$')
      THEN
          CAST (facing AS varchar2(30))
      ELSE
          NULL
      END
          AS facing,  
  CASE
      WHEN REGEXP_LIKE (veneer, '^-?[[:alpha:],.]*$')
      THEN
          CAST (veneer AS varchar2(30))
      ELSE
          NULL
      END
          AS veneer, 
  
  CASE
      WHEN REGEXP_LIKE (function_type, '')
      THEN
          NULL
      ELSE
          CAST (function_type as varchar2(50))
      END
          AS function_type,
  CASE
      WHEN REGEXP_LIKE (max_wall_height_ft, '^-?[[:digit:],.]*$')
      THEN
          CAST (max_wall_height_ft AS number)
      ELSE
          NULL
      END
          AS max_wall_height_ft,
  CASE
      WHEN REGEXP_LIKE (total_length_ft, '^-?[[:digit:],.]*$')
      THEN
          CAST (total_length_ft AS number)
      ELSE
          NULL
      END
          AS total_length_ft,
  CASE
      WHEN length(street) >1
      THEN
          CAST (street AS varchar2(40))
      ELSE
          NULL
      END
          AS street,
  SUBSTR("CULVERT_NUMBER", 1,100) as culvert_number,
  SUBSTR("LOCATION_DESCRIPTION", 1,200) as location_description,
  SUBSTR("BRIDGE_NUMBER", 1,200) as bridge_number

 

  
  

FROM
  EXT_RETAINING_WALLS;
