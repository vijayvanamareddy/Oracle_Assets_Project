CREATE OR REPLACE PROCEDURE P_WRITE_PUBLIC_PRIVATE_ROAD_REPORT_TO_FILE
AS
 /**********************************************************************
    This procedure writes the xml for the public private road report to disk.  It is created
    from the view V_PUBLIC_PRIVATE_ROADS.  DOTDW-937

    07-19-2024 S Hillson - Initial Version
    
    *********************************************************************/
myLOB CLOB;
begin
SELECT  public_private_roads INTO myLOB FROM  V_PUBLIC_PRIVATE_ROADS;
dbms_xslprocessor.clob2file(mylob, 'EXT_DIR_OBIDW', 'public_private_roads.xml');
end;
/
