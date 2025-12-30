CREATE OR REPLACE VIEW WH_ASSETS.POSTED_FOR_UNDERCLEARANCE
BEQUEATH DEFINER
AS 
(SELECT I.bridge_number,
            bridge_name,
            OL_NORTH_MAIN_POSTED,
            OL_NORTH_MAIN_POSTED_FT,
            OL_NORTH_MAIN_POSTED_IN,
            OL_NORTH_OTHER_POSTED,
            OL_NORTH_OTHER_POSTED_FT,
            OL_NORTH_OTHER_POSTED_IN,
            OL_NORTH_RAMP_POSTED,
            OL_NORTH_RAMP_POSTED_FT,
            OL_NORTH_RAMP_POSTED_IN,
            OL_SOUTH_MAIN_POSTED,
            OL_SOUTH_MAIN_POSTED_FT,
            OL_SOUTH_MAIN_POSTED_IN,
            OL_SOUTH_OTHER_POSTED,
            OL_SOUTH_OTHER_POSTED_FT,
            OL_SOUTH_OTHER_POSTED_IN,
            OL_SOUTH_RAMP_POSTED,
            OL_SOUTH_RAMP_POSTED_FT,
            OL_SOUTH_RAMP_POSTED_IN,
            OL_PORTAL_NORTH_POSTED,
            OL_PORTAL_NORTH_POSTED_FT,
            OL_PORTAL_NORTH_POSTED_IN,
            OL_PORTAL_SOUTH_POSTED,
            OL_PORTAL_SOUTH_POSTED_FT,
            OL_PORTAL_SOUTH_POSTED_IN
       FROM ibridges  I
      WHERE (   OL_NORTH_MAIN_POSTED = 'True'
             OR OL_NORTH_OTHER_POSTED = 'True'
             OR OL_NORTH_RAMP_POSTED = 'True'
             OR OL_PORTAL_NORTH_POSTED = 'True'
             OR OL_PORTAL_SOUTH_POSTED = 'True'
             OR OL_SOUTH_MAIN_POSTED = 'True'
             OR OL_SOUTH_OTHER_POSTED = 'True'
             OR OL_SOUTH_RAMP_POSTED = 'True'));
