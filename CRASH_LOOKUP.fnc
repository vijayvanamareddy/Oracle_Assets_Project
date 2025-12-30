CREATE OR REPLACE FUNCTION crash_lookup( 
 field_name IN varchar2, 
 cod in varchar2)
 RETURN varchar2
IS

descrip varchar2(100);


CURSOR c (feid in VARCHAR2,  cd IN VARCHAR2) IS
SELECT  SUBSTR(TRIM(description), 1, 100)
FROM mv_crash_lookups
WHERE table_name = feid AND
      id = cd;



BEGIN

descrip := NULL;

OPEN c(field_name, cod);
FETCH c INTO descrip;


CLOSE c;

RETURN (descrip);


EXCEPTION WHEN OTHERS THEN RETURN(NULL);
END;
/
