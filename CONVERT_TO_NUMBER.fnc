CREATE OR REPLACE function convert_to_number(p varchar2) return number is
    v number;
    
    /*  Function to convert varchar data coming from Inspect Tech to Number
    Revision History:
    6-30-2016 SH Return -1 for Invalid data rather than 0 since NBI Condition Ratings and Appraisal Ratings can be 0
    */
    
  begin
       v := to_number(p);
    return v;

  exception when others then return -1;
end;
/
