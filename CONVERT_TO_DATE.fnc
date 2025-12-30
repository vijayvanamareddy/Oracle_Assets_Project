CREATE OR REPLACE function convert_to_date(date_str varchar2,format_mask varchar2) return date is
    d DATE;
    
    /*  Function to convert varchar string data coming from Inspect Tech to Date 
        Returns null for invalid date 
    Revision History:
    8-16-2016 SH Initial Version
    */
    
  begin
       d := TO_DATE (date_str,format_mask);
    return d;

  exception when others then return NULL;
end;
/
