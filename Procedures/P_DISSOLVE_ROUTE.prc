CREATE OR REPLACE PROCEDURE P_DISSOLVE_ROUTE (
    i_where IN NVARCHAR2,
    i_columns IN NVARCHAR2,  
    o_route_recordset OUT SYS_REFCURSOR)
IS
 /**********************************************************************
6-17-2020 TAM Create  WH_ASSETS.DISSOLVE_ROUTE Initial Version
    - Takes the parameters of a 'where' clause and a list of columns and 
      does a MATCH RECOGNIZE against a DENSE_RANKED PARTITION of the list
      of columns to get a MIN/MAX of the section mile points. This in a sense dissolves 
      the column values together to represent consecutive route mile points.  
11-13-2020 SH Add parameter suppress_reporting when writing to tberrlog so will not be reported
      as critical in daily summary report
 **********************************************************************/

SQLMSG   VARCHAR2 (400);

BEGIN
    OPEN o_route_recordset FOR
          'SELECT *
            FROM (  SELECT route_number, MIN (begin_section_mp) AS begin_section_mp, MAX (end_section_mp) AS end_section_mp, ' || i_columns || '
                      FROM (SELECT *
                              FROM (  SELECT route_number, begin_section_mp, end_section_mp, ' || i_columns || ',  DENSE_RANK () OVER (PARTITION BY ' || i_columns || '  ORDER BY route_number, begin_section_mp) AS ds_rn
                                        FROM v_complete_transp_network
                                       WHERE  ' || i_where || ' 
                                    ORDER BY route_number, begin_section_mp)                         
                                       MATCH_RECOGNIZE (                                         
                                           ORDER BY route_number, begin_section_mp, end_section_mp, ds_rn
                                           MEASURES classifier () AS var, match_number () AS grp
                                           ALL ROWS PER MATCH
                                           PATTERN (strt consecutive *)
                                           DEFINE consecutive AS begin_section_mp = (prev (end_section_mp)) AND ds_rn = (prev (ds_rn) + 1)))
                  GROUP BY grp, route_number, ' || i_columns || ' )
        ORDER BY route_number, begin_section_mp' ;
    
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
                     'P_DISSOLVE_ROUTE',
                     'WH_ASSETS',
                     SQLMSG,
                     'Y');

        COMMIT; 
END;
/
