CREATE OR REPLACE FUNCTION Highways_code_lookup( 
 field_name  IN VARCHAR2,
 descr in varchar2)
 RETURN varchar2
IS
-- Looks up a code given the description
cd varchar2(80);

CURSOR c (fld IN VARCHAR2, descrip IN VARCHAR2) IS
SELECT ial_value
FROM nm_inv_attri_lookup
WHERE 
      ial_domain = fld AND
      ial_meaning = descrip;


BEGIN

cd := NULL;

OPEN c (field_name, descr);
FETCH c INTO cd;

CLOSE c;
RETURN (cd);

EXCEPTION WHEN OTHERS THEN RETURN(NULL);
END;
/
