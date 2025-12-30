CREATE OR REPLACE FUNCTION crash_lookupi( 
 tab_name IN varchar2, 
 cod in varchar2)
 RETURN varchar2
IS
/* SH - Use implicit cursor for lookup */
descrip varchar2(100);
err   VARCHAR2 (100);
g_start_time                     DATE := SYSDATE;

BEGIN

SELECT  SUBSTR(TRIM(description), 1, 100) into descrip
FROM mv_crash_lookups
WHERE table_name = tab_name AND
      id = cod;

RETURN descrip;

    EXCEPTION
        WHEN OTHERS
        THEN
            err :=
                   'Error num :'
                || TO_CHAR (SQLCODE)
                || ' '
                || SUBSTR (SQLERRM, 1, 70);

            INSERT INTO data_exceptions (table_name,
                                         error_condition,
                                         test_procedure,
                                         test_date,
                                         assessment,
                                         column_name1,
                                         column_value1,
                                         column_name2,
                                         column_value2,
                                         column_name3,
                                         column_value3)
                 VALUES ('accidents',
                         err,
                         $$PLSQL_UNIT,
                         g_start_time,
                         'BAD CODE',
                         'FUNCTION',
                         'Crash_lookup',
                          'TABLE',
                         tab_name,
                         'CODE',
                         cod);
                         RETURN NULL;
    END;
/
