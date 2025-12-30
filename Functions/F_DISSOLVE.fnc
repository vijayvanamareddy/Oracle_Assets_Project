CREATE OR REPLACE FUNCTION F_DISSOLVE (
    i_route_id IN NVARCHAR2,
    i_bmp IN NVARCHAR2,
    i_emp IN NVARCHAR2,
    i_table IN NVARCHAR2,
    i_columns IN NVARCHAR2,
    i_where IN NVARCHAR2
    )
    RETURN SYS_REFCURSOR  
AS
 /**********************************************************************
9-18-2020 TAM Create WH_ASSETS.F_DISSOLVE Initial Version
      
 **********************************************************************/
o_route_recordset SYS_REFCURSOR;
SQLMSG   VARCHAR2 (400);

BEGIN
    DBMS_OUTPUT.PUT_LINE(i_route_id || ' | ' || i_bmp || ' | ' || i_emp || ' | ' || i_table || ' | ' || i_columns || ' | ' || i_where );  
    OPEN o_route_recordset FOR
          'SELECT *
            FROM (  SELECT ' || i_route_id || ', MIN (' || i_bmp || ') AS ' || i_bmp || ', MAX (' || i_emp || ') AS ' || i_emp || ' , ' || i_columns || '
                      FROM (SELECT *
                              FROM (  SELECT ' || i_route_id || ', ' || i_bmp || ', ' || i_emp || ', ' || i_columns || ',  DENSE_RANK () OVER (PARTITION BY ' || i_columns || '  ORDER BY ' || i_route_id || ', ' || i_bmp || ') AS ds_rn
                                        FROM ' || i_table || ' 
                                       WHERE  ' || i_where || ' 
                                    ORDER BY ' || i_route_id || ', ' || i_bmp || ')                         
                                       MATCH_RECOGNIZE (                                         
                                           ORDER BY ' || i_route_id || ', ' || i_bmp || ', ' || i_emp || ', ds_rn
                                           MEASURES classifier () AS var, match_number () AS grp
                                           ALL ROWS PER MATCH
                                           PATTERN (strt consecutive *)
                                           DEFINE consecutive AS ' || i_bmp || ' = (prev (' || i_emp || ')) AND ds_rn = (prev (ds_rn) + 1)))
                  GROUP BY grp, ' || i_route_id || ', ' || i_columns || ' )
        ORDER BY ' || i_route_id || ', ' || i_bmp || '' ;
        RETURN o_route_recordset;
    EXCEPTION
    WHEN OTHERS
    THEN
        SQLMSG := SUBSTR (SQLERRM, 1, 400);

        INSERT INTO WH_COMMON.TBERRLOG (ERR_DATETIME,
                                        ERR_MODULE,
                                        ERR_OID,
                                        ERR_MESSAGE,
                                        SUPPRESS_REPORTING)
             VALUES (SYSDATE,
                     'F_DISSOLVE',
                     'WH_ASSETS',
                     SQLMSG,
                     'Y');

        COMMIT; 
END;
/
