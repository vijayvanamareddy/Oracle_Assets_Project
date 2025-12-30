CREATE OR REPLACE PROCEDURE "CINDY_P_TOWN1_PREP" (cp_rowid IN VARCHAR2) IS

/*	psheedy 4/20/2006

	This procedure is run AFTER the TOWN1_PREP table is populated from view VR_TOWN1_REPORT.
	The procedure does the following:

		 - populates the BREAKPOINT column with a zero if the node is in sequence along
		   a route, or with the prim_emp if the node begins after a break in the route.  This
		   column was added to the TOWN1_PREP table to address the bug where gaps within
		   jurisdiction along a route were hidden.

     SHillson 1/25/22 Candidate for deletion - replaced by v_dissolved_lrap and mv_dissolved_lrap ??
*/


CURSOR cur_town1 IS
	SELECT rowid,
		towncode,
		juriscd,
		prirtecode,
		strtname,
		prim_bmp,
		prim_emp,
		boffset,
		eoffset,
		low_node,
		high_node,
		segment_id,
		link_length
	FROM CINDY_TOWN1_PREP
	ORDER BY towncode,juriscd,prirtecode,prim_bmp;
cursor ysa is SELECT   towncode, juriscd, prirtecode, LINK_id,
                            SUM (seglen) segsum
                       FROM CINDY_town1_prep
                   GROUP BY towncode, juriscd, prirtecode, LINK_id;

t_tideyear	NUMBER(4);
t_commit	NUMBER(4);

t_towncode	CINDY_TOWN1_PREP.TOWNCODE%TYPE;
t_juriscd	CINDY_TOWN1_PREP.JURISCD%TYPE;
t_prirtecode	CINDY_TOWN1_PREP.PRIRTECODE%TYPE;
t_strtname	CINDY_TOWN1_PREP.STRTNAME%TYPE;

t_emp		CINDY_TOWN1_PREP.PRIM_EMP%TYPE;
t_boffset	CINDY_TOWN1_PREP.BOFFSET%TYPE;
t_eoffset	CINDY_TOWN1_PREP.EOFFSET%TYPE;

t_firstnode	CINDY_TOWN1_PREP.LOW_NODE%TYPE;
t_lastnode	CINDY_TOWN1_PREP.HIGH_NODE%TYPE;

t_breakpoint	CINDY_TOWN1_PREP.PRIM_BMP%TYPE;

t_rowid		VARCHAR2(32);
t_firstrec	NUMBER(1);
t_direction	NUMBER(1);

/******************************************************************

			MAIN PROGRAM

******************************************************************/
BEGIN

	--p_load_history(cp_rowid,'IN PROGRESS');
    DELETE FROM CINDY_town1_prep;
	COMMIT;
    --p_tideload_scriptrunner('DROP_IDXS_TOWN1_PREP.SQL'); 
    
	INSERT INTO CINDY_town1_prep select * from CINDY_vr_town1_report;

	--t_tideyear	:= f_gettideyear;
	t_breakpoint	:= 0;
	t_towncode	:= NULL;
	t_juriscd	:= NULL;
	t_prirtecode	:= NULL;
	t_strtname	:= NULL;
	t_emp		:= NULL;
	t_firstrec	:= 0;
	t_commit	:= 0;
    --p_tideload_scriptrunner('CREATE_IDXS_TOWN1_PREP.SQL');
	/*UPDATE TIDEAPPS.town1_prep a
	SET segsum = 	(SELECT segsum FROM (SELECT towncode,juriscd,prirtecode,link_id,sum(seglen) segsum
					FROM tideapps.town1_prep
					GROUP BY towncode,juriscd,prirtecode,link_id) b
			WHERE a.towncode = b.towncode AND
			  a.juriscd = b.juriscd AND
			  a.prirtecode = b.prirtecode AND
			  a.link_id = b.link_id);

	COMMIT; */
    FOR rec IN ysa lOOP
       UPDATE CINDY_town1_prep a
       SET segsum = rec.segsum   
            WHERE a.towncode = rec.towncode
                  AND a.juriscd = rec.juriscd
                  AND a.prirtecode = rec.prirtecode
                  AND a.link_id = rec.link_id;
    END LOOP;
    COMMIT;
	FOR c_town1 IN cur_town1 LOOP

		t_rowid		:= c_town1.rowid;

		IF t_towncode = c_town1.towncode AND t_juriscd = c_town1.juriscd AND
			t_prirtecode = c_town1.prirtecode THEN

			IF (t_emp <> c_town1.prim_bmp) or (t_strtname <> c_town1.strtname) THEN
				t_breakpoint	:= c_town1.prim_emp;
			END IF;
		ELSE
			t_breakpoint	:= 0;
		END IF;

		t_boffset	:= c_town1.boffset;
		t_eoffset	:= (c_town1.link_length - c_town1.eoffset) * -1;
		--t_eoffset	:= (c_town1.link_length - c_town1.eoffset) * -1;

		UPDATE CINDY_TOWN1_PREP SET breakpoint = t_breakpoint,
					low_node_offset = t_boffset,
					high_node_offset = t_eoffset
				WHERE rowid = t_rowid;

		t_towncode	:= c_town1.towncode;
		t_juriscd	:= c_town1.juriscd;
		t_prirtecode	:= c_town1.prirtecode;
		t_strtname	:= c_town1.strtname;
		t_emp		:= c_town1.prim_emp;

		IF t_commit > 200 THEN
			t_commit	:= 0;
			COMMIT;
		END IF;

	END LOOP;

--	p_load_history(cp_rowid,'COMPLETE');
	COMMIT;
EXCEPTION WHEN OTHERS THEN
	--p_load_history(cp_rowid,'FAILED');
--	p_error(
--		'p_town1_prep',
--		'',
--		'',
--		'',
--		'',
--		'P',
--		'Error num :'||to_char(sqlcode)||' '||substr(sqlerrm,1,60),
--		'5');
COMMIT;
END;
/
