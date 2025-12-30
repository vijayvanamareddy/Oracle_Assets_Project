CREATE OR REPLACE FUNCTION Bridge_lookup( 
 fe_id IN varchar2, 
 cod in varchar2,
 desc_length in number)
 RETURN varchar2
IS

descrip varchar2(120);


CURSOR c (feid in VARCHAR2,  cd IN VARCHAR2) IS
SELECT  SUBSTR(TRIM(description), 1, desc_length)
FROM bridges_lookup_codes
WHERE field_id = feid AND
      code = cd;



BEGIN

descrip := NULL;

OPEN c(fe_id, cod);
FETCH c INTO descrip;


CLOSE c;

RETURN (descrip);


EXCEPTION WHEN OTHERS THEN RETURN(NULL);
END;
/
