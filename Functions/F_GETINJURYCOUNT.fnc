CREATE OR REPLACE FUNCTION F_GETINJURYCOUNT (
    cp_crid      IN integer,
    cp_injurydegree IN integer
)
RETURN NUMBER IS
/* Initial Version, copied from tide */

t_return pls_integer := -1;
t_injury_cnt pls_integer;

BEGIN

 t_return := -1;
 if cp_injurydegree != 99 then -- 99 code to get count of all injuries
      SELECT sum(injcount) into t_return FROM mv_crash_injurycount  WHERE crashreportid = cp_crid AND injurydegree = cp_injurydegree;
 else
      SELECT sum(injcount) into t_return FROM mv_crash_injurycount  WHERE crashreportid = cp_crid AND injurydegree between 1 and 4;
 end if;
 RETURN ( nvl(t_return,0) );
EXCEPTION WHEN OTHERS THEN
 RETURN(-1);

END;
/
