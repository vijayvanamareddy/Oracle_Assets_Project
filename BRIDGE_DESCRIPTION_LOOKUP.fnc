CREATE OR REPLACE FUNCTION Bridge_description_lookup( 
 table_name IN VARCHAR2,
 field_name  IN VARCHAR2,
 code in varchar2,
 desc_length in number)
 RETURN varchar2
IS

description varchar2(120);

CURSOR c (tab in VARCHAR2, fld IN VARCHAR2, cd IN VARCHAR2) IS
SELECT SUBSTR(TRIM(longdesc), 1, desc_length)
FROM pontis_paramtrs 
WHERE table_name = tab AND
      field_name = fld AND
      parmvalue = code;



BEGIN

description := NULL;

OPEN c(table_name, field_name, code);
FETCH c INTO description;

CLOSE c;

RETURN (description);


EXCEPTION WHEN OTHERS THEN RETURN(NULL);
END;
/
