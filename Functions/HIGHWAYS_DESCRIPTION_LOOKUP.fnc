CREATE OR REPLACE FUNCTION Highways_description_lookup( 
 field_name  IN VARCHAR2,
 code in varchar2,
 desc_length in number)
 RETURN varchar2
IS

description varchar2(80);

CURSOR c (fld IN VARCHAR2, cd IN VARCHAR2) IS
SELECT SUBSTR(TRIM(ial_meaning), 1, desc_length)
FROM nm_inv_attri_lookup
WHERE 
      ial_domain = fld AND
      ial_value = code;



BEGIN

description := NULL;

OPEN c (field_name, code);
FETCH c INTO description;

CLOSE c;
RETURN (description);

EXCEPTION WHEN OTHERS THEN RETURN(NULL);
END;
/
