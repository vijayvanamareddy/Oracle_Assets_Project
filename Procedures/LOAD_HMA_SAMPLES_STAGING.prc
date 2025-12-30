CREATE OR REPLACE PROCEDURE LOAD_HMA_SAMPLES_STAGING
IS
/**********************************************************************
    This procedure loads the HMA (hot mix asphault) staging data from the TIMS system.

    It truncates the table and re-loads it weekly.

    12-03-2024 DG  DOTDW-981 Initial Version
    12-31-2024 DG  DOTDW-981 Add Plant Number
  
**********************************************************************/

    commit_count   NUMBER (7) := 0;
    cntr           NUMBER (7) := 0;

    g_start_time   DATE := SYSDATE;
    g_owner        VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname      VARCHAR2 (30) := 'LOAD_HMA_SAMPLES_STAGING';
    g_object       VARCHAR2 (20) := 'HMA_SAMPLES_STAGING';
    g_sqlmsg       VARCHAR2 (500) := NULL;

    CURSOR hma_samples IS 
    SELECT DISTINCT
       TLOG.PINIDNO AS CONTRACT_NUMBER, 
       TCOMP.COMPANY_NAME, 
       TCOMP.COMPANY_LOCATION AS PLANT_LOCATION, 
       TCOMP.COMPANY_NAME || ' - ' || TCOMP.COMPANY_LOCATION AS COMPANY_PLANT, 
       TCOMP.BUILDING_LAT,
       TCOMP.BUILDING_LONG,
       TLIST.PLANT_NUMBER,
       EXTRACT(YEAR FROM TLOG.SAMPLED_DATE) AS SAMPLE_YEAR, 
       EXTRACT(MONTH FROM TLOG.SAMPLED_DATE) AS SAMPLE_MONTH, 
       EXTRACT(DAY FROM TLOG.SAMPLED_DATE) AS SAMPLE_DOM, 
       TLOG.REFERENCE_IDNO, 
       TLOG.SAMPLED_DATE, 
       TDESC.SAMPLE_DESCRIPTION, 
       TLOG.ITEM_NO, 
       TLOG.SUBLOT_SIZE AS QTY
    FROM (TBLSAMPLELOG@TIMS TLOG INNER JOIN TBLSAMPLEDESCRIPTION@TIMS TDESC ON TLOG.SAMPLE_IDNO = TDESC.SAMPLE_IDNO) 
   INNER JOIN TBLCOMPANY@TIMS TCOMP ON TLOG.PLANT_IDNO = TCOMP.COMPANY_IDNO
   LEFT OUTER JOIN (TBLHMA_DESIGN_DATA@TIMS TDDATA INNER JOIN TBLHMA_DESIGN_ADD_JMN@TIMS TDADD ON TDDATA.JOB_MIX_NO = TDADD.JOB_MIX_NO) ON TLOG.JOB_MIX_NO = TDADD.ADD_JMN 
   LEFT OUTER JOIN TBLLIST_HMA_PLANTS@TIMS TLIST ON TDDATA.PLT_NO = TLIST.HMA_PLANT_IDNO
   WHERE TDESC.SAMPLE_DESCRIPTION LIKE 'HMA M%' AND TLOG.SUBLOT_SIZE IS NOT NULL
    ;

BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE WH_ASSETS.HMA_SAMPLES_STAGING';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE WH_ASSETS.HMA_SAMPLES_STAGING_ERROR_LOG';

    FOR rec IN hma_samples
    LOOP
        
        INSERT INTO WH_ASSETS.HMA_SAMPLES_STAGING (
            CONTRACT_NUMBER     ,         
            COMPANY_NAME        ,     
            PLANT_LOCATION      ,     
            COMPANY_PLANT       ,    
            BUILDING_LAT        ,
            BUILDING_LONG       ,
            PLANT_NUMBER        ,
            SAMPLE_YEAR         ,     
            SAMPLE_MONTH        ,     
            SAMPLE_DOM          ,
            REFERENCE_IDNO      ,     
            SAMPLED_DATE        ,     
            SAMPLE_DESCRIPTION  ,     
            ITEM_NO             ,     
            QTY
            ) VALUES (
            rec.CONTRACT_NUMBER     ,         
            rec.COMPANY_NAME        ,     
            rec.PLANT_LOCATION      ,     
            rec.COMPANY_PLANT       ,  
            rec.BUILDING_LAT        ,
            rec.BUILDING_LONG       ,  
            rec.PLANT_NUMBER,
            rec.SAMPLE_YEAR         ,     
            rec.SAMPLE_MONTH        ,     
            rec.SAMPLE_DOM          ,
            rec.REFERENCE_IDNO      ,     
            rec.SAMPLED_DATE        ,     
            rec.SAMPLE_DESCRIPTION  ,     
            rec.ITEM_NO             ,     
            rec.QTY 
            )
            LOG ERRORS INTO WH_ASSETS.HMA_SAMPLES_STAGING_ERROR_LOG
                ('Load HMA Samples ' || SYSDATE)
                REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;

    SELECT COUNT (*) INTO cntr FROM WH_ASSETS.HMA_SAMPLES_STAGING;
    
    WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
        OWNER         => G_OWNER,
        OBJECT_NAME   => g_object,
        object_cnt    => cntr,
        proc          => $$PLSQL_UNIT,
        start_time    => g_start_time);

EXCEPTION
    WHEN OTHERS
    THEN
        G_SQLMSG := $$PLSQL_UNIT || ': ' || SUBSTR (SQLERRM, 1, 400);
        WH_COMMON.PKG_COMMON_UTILITIES.UPDATE_WHSE_LOG (
            OWNER         => G_OWNER,
            OBJECT_NAME   => g_object,
            MSG           => G_SQLMSG,
            STATUS        => 'Failed');

        WH_COMMON.PKG_COMMON_UTILITIES.EXIT_AND_REPORT (
            g_jobname,
            'FAILURE',
            $$PLSQL_UNIT || ' ' || SUBSTR (SQLERRM, 1, 400));
END;
/
