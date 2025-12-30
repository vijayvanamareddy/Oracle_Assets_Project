CREATE OR REPLACE FUNCTION Compare( 
 x IN VARCHAR2,
 y  IN VARCHAR2)
 RETURN boolean
 /*******************************************************
 Function to Compare two Strings Taking Nulls into account
 *******************************************************/
IS

equals boolean;


BEGIN

equals := TRUE;
 
IF (X IS NULL AND Y IS NOT NULL) 
    OR  (Y IS NULL AND X IS NOT NULL)
    OR  (X <> Y) 
THEN equals := FALSE;
END IF;


RETURN (equals);


EXCEPTION WHEN OTHERS THEN RETURN(NULL);
END;
/
