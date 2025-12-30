CREATE OR REPLACE PROCEDURE load_accident_comm_carrier
IS
    /**********************************************************************
    This procedure loads the ACCIDENT_COMMERCIAL_CARRIER table from CRASH.

    It truncates the table and re-loads it.

    07-14-17 SH  Initial Version
    07-26-17 SH  Add carrier_state_descr
    08-01-17 SH Modified to use local function call to get injury count (f_getinjurycount) based on local materialized view, MV_CRASH_INJURYCOUNT
    08-17-17 SH Remove crash_id, add standard error handling, run weekly in assets_cycle
    08-21-17 SH Add columns accident_year and HAZMAT_4DIGIT_NUM
    09-19-17 SH Use implicit cursor for lookups Function crash_lookupi
    09-19-19 SH Add crashreportid and only add crashes in the accidents table in preparation for loading commercial carrier daily
    **********************************************************************/



    commit_count            NUMBER (7) := 0;
    cntr                    NUMBER (7) := 0;

    g_start_time            DATE := SYSDATE;
    g_owner                 VARCHAR2 (20) := 'WH_ASSETS';
    g_jobname               VARCHAR2 (30) := 'LOAD_ACCIDENT_COMM_CARRIER';
    g_object                VARCHAR2 (20) := 'COMMERCIAL_CARRIER';
    g_sqlmsg                VARCHAR2 (500) := NULL;

    tbus_use_descr          accident_commercial_carrier.bus_use_descr%TYPE;
    tcargo_code_descr       accident_commercial_carrier.cargo_code_descr%TYPE;
    tcarrier_type_descr     accident_commercial_carrier.carrier_type_descr%TYPE;
    tcommodity_descr        accident_commercial_carrier.commodity_descr%TYPE;
    tcargo_bodytype_descr   accident_commercial_carrier.cargo_bodytype_descr%TYPE;
    tcarrier_state_descr    accident_commercial_carrier.carrier_state_descr%TYPE;
    thazmat_class_descr     accident_commercial_carrier.hazmat_class_descr%TYPE;
    thazmat_released        accident_commercial_carrier.hazmat_released%TYPE;
    tpermit_overheight      accident_commercial_carrier.permit_overheight%TYPE;
    tpermit_overlength      accident_commercial_carrier.permit_overlength%TYPE;
    tpermit_overweight      accident_commercial_carrier.permit_overweight%TYPE;
    tpermit_overwidth       accident_commercial_carrier.permit_overwidth%TYPE;

    CURSOR acc
    IS
        SELECT a.accident_year,
               cc.bususe,
               cc.cargobodytype,
               cc.cargocode,
               cc.motorcarriertype,
               cc.carriercityortown,
               cc.carriername,
               cc.carrierstate,
               cc.carrierstreetaddress,
               cc.carrierzipcode,
               cc.commoditycode,
               cc.crashreportid,
               cc.hazmat4digitnumber,
               cc.hazmatclassnumber,
               cc.washazardousmaterialsreleased,
               cc.mcmxnumber,
               a.mdotid,
               cc.oversizepermitheight,
               cc.oversizepermitlength,
               cc.oversizepermitweight,
               cc.oversizepermitwidth,
               cc.unitid,
               cc.usdotnumber
          FROM accidents a, commercial@crash cc
         WHERE cc.crashreportid = a.crashreportid;
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ACCIDENT_COMMERCIAL_CARRIER';

    EXECUTE IMMEDIATE 'TRUNCATE TABLE ACCIDENT_CC_ERROR_LOG';


    FOR a IN acc
    LOOP
        -- Lookup descriptions

        IF a.bususe IS NULL
        THEN
            tbus_use_descr := NULL;
        ELSE
            tbus_use_descr := crash_lookupI ('BUS_USE', a.bususe);
        END IF;

        IF a.cargocode IS NULL
        THEN
            tcargo_code_descr := NULL;
        ELSE
            tcargo_code_descr := crash_lookupi ('CARGO_CODE', a.cargocode);
        END IF;

        IF a.motorcarriertype IS NULL
        THEN
            tcarrier_type_descr := NULL;
        ELSE
            tcarrier_type_descr :=
                crash_lookupi ('CARRIER_TYPE', a.motorcarriertype);
        END IF;

        IF a.commoditycode IS NULL
        THEN
            tcommodity_descr := NULL;
        ELSE
            tcommodity_descr := crash_lookupi ('COMMODITY', a.commoditycode);
        END IF;

        IF a.cargobodytype IS NULL
        THEN
            tcargo_bodytype_descr := NULL;
        ELSE
            tcargo_bodytype_descr :=
                crash_lookupi ('CARGO_BODYTYPE', a.cargobodytype);
        END IF;

        IF a.carrierstate IS NULL
        THEN
            tcarrier_state_descr := NULL;
        ELSE
            tcarrier_state_descr :=
                crash_lookupi ('LICENSE_STATE', a.carrierstate);
        END IF;

        IF a.hazmatclassnumber IS NULL
        THEN
            thazmat_class_descr := NULL;
        ELSE
            thazmat_class_descr :=
                crash_lookupi ('HAZMAT_CLASS', a.hazmatclassnumber);
        END IF;

        IF    a.washazardousmaterialsreleased IS NULL
           OR a.washazardousmaterialsreleased = 0
        THEN
            thazmat_released := NULL;
        ELSE
            thazmat_released :=
                crash_lookupi ('YES_NO_UNKOWN',
                               a.washazardousmaterialsreleased);
        END IF;

        IF a.oversizepermitheight IS NULL OR a.oversizepermitheight = 0
        THEN
            tpermit_overheight := NULL;
        ELSE
            tpermit_overheight :=
                crash_lookupi ('YES_NO_UNKOWN', a.oversizepermitheight);
        END IF;

        IF a.oversizepermitlength IS NULL OR a.oversizepermitlength = 0
        THEN
            tpermit_overlength := NULL;
        ELSE
            tpermit_overlength :=
                crash_lookupi ('YES_NO_UNKOWN', a.oversizepermitlength);
        END IF;

        IF a.oversizepermitweight IS NULL OR a.oversizepermitweight = 0
        THEN
            tpermit_overweight := NULL;
        ELSE
            tpermit_overweight :=
                crash_lookupi ('YES_NO_UNKOWN', a.oversizepermitweight);
        END IF;

        IF a.oversizepermitwidth IS NULL OR a.oversizepermitwidth = 0
        THEN
            tpermit_overwidth := NULL;
        ELSE
            tpermit_overwidth :=
                crash_lookupi ('YES_NO_UNKOWN', a.oversizepermitwidth);
        END IF;


        INSERT INTO ACCIDENT_COMMERCIAL_CARRIER (accident_year,
                                                 bus_use,
                                                 bus_use_descr,
                                                 cargo_bodytype,
                                                 cargo_bodytype_descr,
                                                 cargo_code,
                                                 cargo_code_descr,
                                                 carrier_city,
                                                 carrier_name,
                                                 carrier_state,
                                                 carrier_state_descr,
                                                 carrier_street,
                                                 carrier_type,
                                                 carrier_type_descr,
                                                 carrier_zip,
                                                 commodity,
                                                 commodity_descr,
                                                 crashreportid,
                                                 hazmat_4digit_num,
                                                 hazmat_class,
                                                 hazmat_class_descr,
                                                 hazmat_released,
                                                 mcmx_no,
                                                 mdotid,
                                                 permit_overheight,
                                                 permit_overlength,
                                                 permit_overweight,
                                                 permit_overwidth,
                                                 unit_id,
                                                 usdot_no)
             VALUES (a.accident_year,
                     a.bususe,
                     tbus_use_descr,
                     a.cargobodytype,
                     tcargo_bodytype_descr,
                     a.cargocode,
                     tcargo_code_descr,
                     a.carriercityortown,
                     a.carriername,
                     a.carrierstate,
                     tcarrier_state_descr,
                     a.carrierstreetaddress,
                     a.motorcarriertype,
                     tcarrier_type_descr,
                     a.carrierzipcode,
                     a.commoditycode,
                     tcommodity_descr,
                     a.crashreportid,
                     a.hazmat4digitnumber,
                     a.hazmatclassnumber,
                     thazmat_class_descr,
                     thazmat_released,
                     a.mcmxnumber,
                     a.mdotid,
                     tpermit_overheight,
                     tpermit_overlength,
                     tpermit_overweight,
                     tpermit_overwidth,
                     a.unitid,
                     a.usdotnumber)
                LOG ERRORS INTO accident_cc_error_log
                        ('LOAD ACCIDENT COMMERCIAL CARRIER ' || SYSDATE)
                        REJECT LIMIT 100;

        commit_count := commit_count + 1;

        IF commit_count > 10000
        THEN
            COMMIT;
            commit_count := 0;
        END IF;
    END LOOP;

    COMMIT;

    SELECT COUNT (*) INTO cntr FROM ACCIDENT_COMMERCIAL_CARRIER;

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
        RAISE_APPLICATION_ERROR (-20010, G_SQLMSG);
END;
/
