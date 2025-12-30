CREATE OR REPLACE VIEW WH_ASSETS.V_SNBI_BRIDGES
BEQUEATH DEFINER
AS 
select "BRIDGE_NUMBER","BRIDGE_NAME", "STATE_CODE", "COUNTY_CODE", "PLACE_CODE", "HIGHWAY_AGENCY_DISTRICT", "LATITUDE", "LONGITUDE", "BORDER_BRIDGE_NUMBER", "BORDER_BRIDGE_STATE_OR_COUNTRY_CODE",
       "BORDER_BRIDGE_INSPECTION_RESPONSIBILITY", "BORDER_BRIDGE_DESIGNATED_LEAD_STATE", "BRIDGE_LOCATION", "METROPOLITAN_PLANNING_ORGANIZATION",
       "OWNER", "MAINTENANCE_RESPONSIBILITY", "FEDERAL_OR_TRIBAL_LAND_ACCESS", "HISTORIC_SIGNIFICANCE", "TOLL", "EMERGENCY_EVACUATION_DESIGNATION",
       "BRIDGE_RAILINGS", "TRANSITIONS", 
       "NBIS_BRIDGE_LENGTH","TOTAL_BRIDGE_LENGTH", "MAXIMUM_SPAN_LENGTH", "MINIMUM_SPAN_LENGTH", "BRIDGE_WIDTH_OUT_TO_OUT", "BRIDGE_WIDTH_CURB_TO_CURB", "LEFT_CURB_OR_SIDEWALK_WIDTH", "RIGHT_CURB_OR_SIDEWALK_WIDTH",
       "APPROACH_ROADWAY_WIDTH", "BRIDGE_MEDIAN", "SKEW", "CURVED_BRIDGE", "MAXIMUM_BRIDGE_HEIGHT", "SIDEHILL_BRIDGE", "IRREGULAR_DECK_AREA", "CALCULATED_DECK_AREA"
from
(select bridge_number, snbi_name, cv_value from EXT_SNBI_BRIDGES) 
pivot (min(cv_value) for snbi_name in (
'Bridge_Name' Bridge_Name,
'State_Code' State_Code,
'County_Code' County_Code,
'Place_Code' Place_Code,
'Highway_Agency_District' Highway_Agency_District,
'Latitude' Latitude,
'Longitude' Longitude,
'Border_Bridge_Number' Border_Bridge_Number,
'Border_Bridge_State_Or_Country_Code' Border_Bridge_State_Or_Country_Code,
'Border_Bridge_Inspection_Responsibility' Border_Bridge_Inspection_Responsibility,
'Border_Bridge_Designated_Lead_State' Border_Bridge_Designated_Lead_State,
'Bridge_Location' Bridge_Location,
'Metropolitan_Planning_Organization' Metropolitan_Planning_Organization,
'Owner' Owner,
'Maintenance_Responsibility' Maintenance_Responsibility,
'Federal_or_Tribal_Land_Access' Federal_or_Tribal_Land_Access,
'Historic_Significance' Historic_Significance,
'Toll' Toll,
'Emergency_Evacuation_Designation' Emergency_Evacuation_Designation,
'Bridge_Railings' Bridge_Railings, 
'Transitions' Transitions, 
'NBIS_Bridge_Length' NBIS_Bridge_Length,
'Total_Bridge_Length' Total_Bridge_Length, 
'Maximum_Span_Length' Maximum_Span_Length, 
'Minimum_Span_Length' Minimum_Span_Length, 
'Bridge_Width_Out_to_Out' Bridge_Width_Out_to_Out, 
'Bridge_Width_Curb_to_Curb' Bridge_Width_Curb_to_Curb, 
'Left_Curb_or_Sidewalk_Width' Left_Curb_or_Sidewalk_Width, 
'Right_Curb_or_Sidewalk_Width' Right_Curb_or_Sidewalk_Width,
'Approach_Roadway_Width' Approach_Roadway_Width, 
'Bridge_Median' Bridge_Median, 
'Skew' Skew, 
'Curved_Bridge' Curved_Bridge, 
'Maximum_Bridge_Height' Maximum_Bridge_Height, 
'Sidehill_Bridge' Sidehill_Bridge, 
'Irregular_Deck_Area' Irregular_Deck_Area, 
'Calculated_Deck_Area' Calculated_Deck_Area

));
