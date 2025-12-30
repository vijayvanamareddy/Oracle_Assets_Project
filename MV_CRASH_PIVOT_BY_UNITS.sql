CREATE MATERIALIZED VIEW MV_CRASH_PIVOT_BY_UNITS
NOCACHE
LOGGING
NOCOMPRESS
NOPARALLEL
NO INMEMORY
BUILD IMMEDIATE
NEVER REFRESH
AS 
SELECT mdotid,
       unit1_most_harmful_event_descr,
       unit2_most_harmful_event_descr,
       unit3_most_harmful_event_descr,
       unit1_most_harmful_event,
       unit2_most_harmful_event,
       unit3_most_harmful_event,
       CASE
           WHEN    unit1_direction_of_travel = 1
                OR unit2_direction_of_travel = 1
                OR unit3_direction_of_travel = 1
           THEN
               1
           ELSE
               0
       END    AS unit_dir_nb,
       CASE
           WHEN    unit1_direction_of_travel = 2
                OR unit2_direction_of_travel = 2
                OR unit3_direction_of_travel = 2
           THEN
               1
           ELSE
               0
       END    AS unit_dir_sb,
       CASE
           WHEN    unit1_direction_of_travel = 3
                OR unit2_direction_of_travel = 3
                OR unit3_direction_of_travel = 3
           THEN
               1
           ELSE
               0
       END    AS unit_dir_eb,
       CASE
           WHEN    unit1_direction_of_travel = 4
                OR unit2_direction_of_travel = 4
                OR unit3_direction_of_travel = 4
           THEN
               1
           ELSE
               0
       END    AS unit_dir_wb,
       CASE
           WHEN    unit1_direction_of_travel IN (5, 6)
                OR unit2_direction_of_travel IN (5, 6)
                OR unit3_direction_of_travel IN (5, 6)
           THEN
               1
           ELSE
               0
       END    AS unit_dir_other,
       CASE
           WHEN    unit1_precrash_actions IN (3,
                                              4,
                                              5,
                                              6,
                                              7)
                OR unit2_precrash_actions IN (3,
                                              4,
                                              5,
                                              6,
                                              7)
                OR unit3_precrash_actions IN (3,
                                              4,
                                              5,
                                              6,
                                              7)
           THEN
               1
           ELSE
               0
       END    AS unit_pre_turn,
       CASE
           WHEN    unit1_precrash_actions IN (9, 10, 11)
                OR unit2_precrash_actions IN (9, 10, 11)
                OR unit3_precrash_actions IN (9, 10, 11)
           THEN
               1
           ELSE
               0
       END    AS unit_pre_traffic,
       CASE
           WHEN    unit1_precrash_actions IN (8,
                                              12,
                                              13,
                                              14)
                OR unit2_precrash_actions IN (8,
                                              12,
                                              13,
                                              14)
                OR unit3_precrash_actions IN (8,
                                              12,
                                              13,
                                              14)
           THEN
               1
           ELSE
               0
       END    AS unit_pre_parking,
       CASE
           WHEN    unit1_precrash_actions IN (17, 18, 19)
                OR unit2_precrash_actions IN (17, 18, 19)
                OR unit3_precrash_actions IN (17, 18, 19)
           THEN
               1
           ELSE
               0
       END    AS unit_pre_lanes,
       CASE
           WHEN    unit1_precrash_actions IN (15, 16)
                OR unit2_precrash_actions IN (15, 16)
                OR unit3_precrash_actions IN (15, 16)
           THEN
               1
           ELSE
               0
       END    AS unit_pre_sudden,
       CASE
           WHEN    unit1_precrash_actions IN (20,
                                              30,
                                              31,
                                              99)
                OR unit2_precrash_actions IN (20,
                                              30,
                                              31,
                                              99)
                OR unit3_precrash_actions IN (20,
                                              30,
                                              31,
                                              99)
           THEN
               1
           ELSE
               0
       END    AS unit_pre_other,
       CASE
           WHEN    unit1_precrash_actions IN (1)
                OR unit2_precrash_actions IN (1)
                OR unit3_precrash_actions IN (1)
           THEN
               1
           ELSE
               0
       END    AS unit_pre_follow_road,
       CASE
           WHEN    unit1_precrash_actions IN (2)
                OR unit2_precrash_actions IN (2)
                OR unit3_precrash_actions IN (2)
           THEN
               1
           ELSE
               0
       END    AS unit_pre_wrong_way,
       CASE
           WHEN    unit1_seq_of_events1 = 8
                OR unit2_seq_of_events1 = 8
                OR unit3_seq_of_events1 = 8
           THEN
               1
           WHEN    unit1_seq_of_events2 = 8
                OR unit2_seq_of_events2 = 8
                OR unit3_seq_of_events2 = 8
           THEN
               1
           WHEN    unit1_seq_of_events3 = 8
                OR unit2_seq_of_events3 = 8
                OR unit3_seq_of_events3 = 8
           THEN
               1
           WHEN    unit1_seq_of_events4 = 8
                OR unit2_seq_of_events4 = 8
                OR unit3_seq_of_events4 = 8
           THEN
               1
           ELSE
               0
       END    WENT_OFF_ROADWAY_RIGHT,
       CASE
           WHEN    unit1_seq_of_events1 = 9
                OR unit2_seq_of_events1 = 9
                OR unit3_seq_of_events1 = 9
           THEN
               1
           WHEN    unit1_seq_of_events2 = 9
                OR unit2_seq_of_events2 = 9
                OR unit3_seq_of_events2 = 9
           THEN
               1
           WHEN    unit1_seq_of_events3 = 9
                OR unit2_seq_of_events3 = 9
                OR unit3_seq_of_events3 = 9
           THEN
               1
           WHEN    unit1_seq_of_events4 = 9
                OR unit2_seq_of_events4 = 9
                OR unit3_seq_of_events4 = 9
           THEN
               1
           ELSE
               0
       END    WENT_OFF_ROADWAY_LEFT,
       CASE
           WHEN    unit1_seq_of_events1 = 11
                OR unit2_seq_of_events1 = 11
                OR unit3_seq_of_events1 = 11
           THEN
               1
           WHEN    unit1_seq_of_events2 = 11
                OR unit2_seq_of_events2 = 11
                OR unit3_seq_of_events2 = 11
           THEN
               1
           WHEN    unit1_seq_of_events3 = 11
                OR unit2_seq_of_events3 = 11
                OR unit3_seq_of_events3 = 11
           THEN
               1
           WHEN    unit1_seq_of_events4 = 11
                OR unit2_seq_of_events4 = 11
                OR unit3_seq_of_events4 = 11
           THEN
               1
           ELSE
               0
       END    cross_centerline,
       CASE
           WHEN    unit1_seq_of_events1 = 1
                OR unit2_seq_of_events1 = 1
                OR unit3_seq_of_events1 = 1
           THEN
               1
           WHEN    unit1_seq_of_events2 = 1
                OR unit2_seq_of_events2 = 1
                OR unit3_seq_of_events2 = 1
           THEN
               1
           WHEN    unit1_seq_of_events3 = 1
                OR unit2_seq_of_events3 = 1
                OR unit3_seq_of_events3 = 1
           THEN
               1
           WHEN    unit1_seq_of_events4 = 1
                OR unit2_seq_of_events4 = 1
                OR unit3_seq_of_events4 = 1
           THEN
               1
           ELSE
               0
       END    overturn_rollover,
       CASE
           WHEN    unit1_seq_of_events1 = 14
                OR unit2_seq_of_events1 = 14
                OR unit3_seq_of_events1 = 14
           THEN
               1
           WHEN    unit1_seq_of_events2 = 14
                OR unit2_seq_of_events2 = 14
                OR unit3_seq_of_events2 = 14
           THEN
               1
           WHEN    unit1_seq_of_events3 = 14
                OR unit2_seq_of_events3 = 14
                OR unit3_seq_of_events3 = 14
           THEN
               1
           WHEN    unit1_seq_of_events4 = 14
                OR unit2_seq_of_events4 = 14
                OR unit3_seq_of_events4 = 14
           THEN
               1
           ELSE
               0
       END    AS reenter_roadway,
       CASE
           WHEN    unit1_seq_of_events1 = 40
                OR unit2_seq_of_events1 = 40
                OR unit3_seq_of_events1 = 40
           THEN
               1
           WHEN    unit1_seq_of_events2 = 40
                OR unit2_seq_of_events2 = 40
                OR unit3_seq_of_events2 = 40
           THEN
               1
           WHEN    unit1_seq_of_events3 = 40
                OR unit2_seq_of_events3 = 40
                OR unit3_seq_of_events3 = 40
           THEN
               1
           WHEN    unit1_seq_of_events4 = 40
                OR unit2_seq_of_events4 = 40
                OR unit3_seq_of_events4 = 40
           THEN
               1
           ELSE
               0
       END    AS utility_pole,
       CASE
           WHEN    unit1_seq_of_events1 = 41
                OR unit2_seq_of_events1 = 41
                OR unit3_seq_of_events1 = 41
           THEN
               1
           WHEN    unit1_seq_of_events2 = 41
                OR unit2_seq_of_events2 = 41
                OR unit3_seq_of_events2 = 41
           THEN
               1
           WHEN    unit1_seq_of_events3 = 41
                OR unit2_seq_of_events3 = 41
                OR unit3_seq_of_events3 = 41
           THEN
               1
           WHEN    unit1_seq_of_events4 = 41
                OR unit2_seq_of_events4 = 41
                OR unit3_seq_of_events4 = 41
           THEN
               1
           ELSE
               0
       END    AS traffic_sign,
       CASE
           WHEN    unit1_seq_of_events1 = 45
                OR unit2_seq_of_events1 = 45
                OR unit3_seq_of_events1 = 45
           THEN
               1
           WHEN    unit1_seq_of_events2 = 45
                OR unit2_seq_of_events2 = 45
                OR unit3_seq_of_events2 = 45
           THEN
               1
           WHEN    unit1_seq_of_events3 = 45
                OR unit2_seq_of_events3 = 45
                OR unit3_seq_of_events3 = 45
           THEN
               1
           WHEN    unit1_seq_of_events4 = 45
                OR unit2_seq_of_events4 = 45
                OR unit3_seq_of_events4 = 45
           THEN
               1
           ELSE
               0
       END    AS mailbox,
       CASE
           WHEN    unit1_seq_of_events1 = 22
                OR unit2_seq_of_events1 = 22
                OR unit3_seq_of_events1 = 22
           THEN
               1
           WHEN    unit1_seq_of_events2 = 22
                OR unit2_seq_of_events2 = 22
                OR unit3_seq_of_events2 = 22
           THEN
               1
           WHEN    unit1_seq_of_events3 = 22
                OR unit2_seq_of_events3 = 22
                OR unit3_seq_of_events3 = 22
           THEN
               1
           WHEN    unit1_seq_of_events4 = 22
                OR unit2_seq_of_events4 = 22
                OR unit3_seq_of_events4 = 22
           THEN
               1
           ELSE
               0
       END    AS parked_vehicle,
       CASE
           WHEN    unit1_seq_of_events1 = 39
                OR unit2_seq_of_events1 = 39
                OR unit3_seq_of_events1 = 39
           THEN
               1
           WHEN    unit1_seq_of_events2 = 39
                OR unit2_seq_of_events2 = 39
                OR unit3_seq_of_events2 = 39
           THEN
               1
           WHEN    unit1_seq_of_events3 = 39
                OR unit2_seq_of_events3 = 39
                OR unit3_seq_of_events3 = 39
           THEN
               1
           WHEN    unit1_seq_of_events4 = 39
                OR unit2_seq_of_events4 = 39
                OR unit3_seq_of_events4 = 39
           THEN
               1
           ELSE
               0
       END    AS tree,
       CASE
           WHEN    unit1_seq_of_events1 = 2
                OR unit2_seq_of_events1 = 2
                OR unit3_seq_of_events1 = 2
           THEN
               1
           WHEN    unit1_seq_of_events2 = 2
                OR unit2_seq_of_events2 = 2
                OR unit3_seq_of_events2 = 2
           THEN
               1
           WHEN    unit1_seq_of_events3 = 2
                OR unit2_seq_of_events3 = 2
                OR unit3_seq_of_events3 = 2
           THEN
               1
           WHEN    unit1_seq_of_events4 = 2
                OR unit2_seq_of_events4 = 2
                OR unit3_seq_of_events4 = 2
           THEN
               1
           ELSE
               0
       END    AS fire_explosion,
       CASE
           WHEN    unit1_seq_of_events1 = 34
                OR unit2_seq_of_events1 = 34
                OR unit3_seq_of_events1 = 34
           THEN
               1
           WHEN    unit1_seq_of_events2 = 34
                OR unit2_seq_of_events3 = 34
                OR unit3_seq_of_events4 = 34
           THEN
               1
           WHEN    unit1_seq_of_events3 = 34
                OR unit2_seq_of_events3 = 34
                OR unit3_seq_of_events3 = 34
           THEN
               1
           WHEN    unit1_seq_of_events4 = 34
                OR unit2_seq_of_events4 = 34
                OR unit3_seq_of_events4 = 34
           THEN
               1
           ELSE
               0
       END    AS embankment,
       CASE
           WHEN    unit1_seq_of_events1 = 33
                OR unit2_seq_of_events1 = 33
                OR unit3_seq_of_events1 = 33
           THEN
               1
           WHEN    unit1_seq_of_events2 = 33
                OR unit2_seq_of_events3 = 33
                OR unit3_seq_of_events4 = 33
           THEN
               1
           WHEN    unit1_seq_of_events3 = 33
                OR unit2_seq_of_events3 = 33
                OR unit3_seq_of_events3 = 33
           THEN
               1
           WHEN    unit1_seq_of_events4 = 33
                OR unit2_seq_of_events4 = 33
                OR unit3_seq_of_events4 = 33
           THEN
               1
           ELSE
               0
       END    AS ditch,
       CASE
           WHEN    unit1_seq_of_events1 = 20
                OR unit2_seq_of_events1 = 20
                OR unit3_seq_of_events1 = 20
           THEN
               1
           WHEN    unit1_seq_of_events2 = 20
                OR unit2_seq_of_events3 = 20
                OR unit3_seq_of_events4 = 20
           THEN
               1
           WHEN    unit1_seq_of_events3 = 20
                OR unit2_seq_of_events3 = 20
                OR unit3_seq_of_events3 = 20
           THEN
               1
           WHEN    unit1_seq_of_events4 = 20
                OR unit2_seq_of_events4 = 20
                OR unit3_seq_of_events4 = 20
           THEN
               1
           ELSE
               0
       END    AS animal,
       CASE
           WHEN    unit1_seq_of_events1 = 35
                OR unit2_seq_of_events1 = 35
                OR unit3_seq_of_events1 = 35
           THEN
               1
           WHEN    unit1_seq_of_events2 = 35
                OR unit2_seq_of_events3 = 35
                OR unit3_seq_of_events4 = 35
           THEN
               1
           WHEN    unit1_seq_of_events3 = 35
                OR unit2_seq_of_events3 = 35
                OR unit3_seq_of_events3 = 35
           THEN
               1
           WHEN    unit1_seq_of_events4 = 35
                OR unit2_seq_of_events4 = 35
                OR unit3_seq_of_events4 = 35
           THEN
               1
           ELSE
               0
       END    AS guardrail_face,
       CASE
           WHEN    unit1_seq_of_events1 = 36
                OR unit2_seq_of_events1 = 36
                OR unit3_seq_of_events1 = 36
           THEN
               1
           WHEN    unit1_seq_of_events2 = 36
                OR unit2_seq_of_events3 = 36
                OR unit3_seq_of_events4 = 36
           THEN
               1
           WHEN    unit1_seq_of_events3 = 36
                OR unit2_seq_of_events3 = 36
                OR unit3_seq_of_events3 = 36
           THEN
               1
           WHEN    unit1_seq_of_events4 = 36
                OR unit2_seq_of_events4 = 36
                OR unit3_seq_of_events4 = 36
           THEN
               1
           ELSE
               0
       END    AS guardrail_end,
       CASE
           WHEN    unit1_seq_of_events1 = 26
                OR unit2_seq_of_events1 = 26
                OR unit3_seq_of_events1 = 26
           THEN
               1
           WHEN    unit1_seq_of_events2 = 26
                OR unit2_seq_of_events3 = 26
                OR unit3_seq_of_events4 = 26
           THEN
               1
           WHEN    unit1_seq_of_events3 = 26
                OR unit2_seq_of_events3 = 26
                OR unit3_seq_of_events3 = 26
           THEN
               1
           WHEN    unit1_seq_of_events4 = 26
                OR unit2_seq_of_events4 = 26
                OR unit3_seq_of_events4 = 26
           THEN
               1
           ELSE
               0
       END    AS impact_attenuator,
       CASE
           WHEN    unit1_seq_of_events1 = 6
                OR unit2_seq_of_events1 = 6
                OR unit3_seq_of_events1 = 6
           THEN
               1
           WHEN    unit1_seq_of_events2 = 6
                OR unit2_seq_of_events3 = 6
                OR unit3_seq_of_events4 = 6
           THEN
               1
           WHEN    unit1_seq_of_events3 = 6
                OR unit2_seq_of_events3 = 6
                OR unit3_seq_of_events3 = 6
           THEN
               1
           WHEN    unit1_seq_of_events4 = 6
                OR unit2_seq_of_events4 = 6
                OR unit3_seq_of_events4 = 6
           THEN
               1
           ELSE
               0
       END    AS equipment_failure,
       CASE
           WHEN    unit1_seq_of_events1 = 37
                OR unit2_seq_of_events1 = 37
                OR unit3_seq_of_events1 = 37
           THEN
               1
           WHEN    unit1_seq_of_events2 = 37
                OR unit2_seq_of_events3 = 37
                OR unit3_seq_of_events4 = 37
           THEN
               1
           WHEN    unit1_seq_of_events3 = 37
                OR unit2_seq_of_events3 = 37
                OR unit3_seq_of_events3 = 37
           THEN
               1
           WHEN    unit1_seq_of_events4 = 37
                OR unit2_seq_of_events4 = 37
                OR unit3_seq_of_events4 = 37
           THEN
               1
           ELSE
               0
       END    AS concrete_traffic_barrier,
       CASE
           WHEN    unit1_seq_of_events1 = 29
                OR unit2_seq_of_events1 = 29
                OR unit3_seq_of_events1 = 29
           THEN
               1
           WHEN    unit1_seq_of_events2 = 29
                OR unit2_seq_of_events3 = 29
                OR unit3_seq_of_events4 = 29
           THEN
               1
           WHEN    unit1_seq_of_events3 = 29
                OR unit2_seq_of_events3 = 29
                OR unit3_seq_of_events3 = 29
           THEN
               1
           WHEN    unit1_seq_of_events4 = 29
                OR unit2_seq_of_events4 = 29
                OR unit3_seq_of_events4 = 29
           THEN
               1
           ELSE
               0
       END    AS bridge_rail,
       CASE
           WHEN    unit1_seq_of_events1 = 46
                OR unit2_seq_of_events1 = 46
                OR unit3_seq_of_events1 = 46
           THEN
               1
           WHEN    unit1_seq_of_events2 = 46
                OR unit2_seq_of_events3 = 46
                OR unit3_seq_of_events4 = 46
           THEN
               1
           WHEN    unit1_seq_of_events3 = 46
                OR unit2_seq_of_events3 = 46
                OR unit3_seq_of_events3 = 46
           THEN
               1
           WHEN    unit1_seq_of_events4 = 46
                OR unit2_seq_of_events4 = 46
                OR unit3_seq_of_events4 = 46
           THEN
               1
           ELSE
               0
       END    AS other_fixed_object,
       CASE
           WHEN    unit1_seq_of_events1 = 10
                OR unit2_seq_of_events1 = 10
                OR unit3_seq_of_events1 = 10
           THEN
               1
           WHEN    unit1_seq_of_events2 = 10
                OR unit2_seq_of_events3 = 10
                OR unit3_seq_of_events4 = 10
           THEN
               1
           WHEN    unit1_seq_of_events3 = 10
                OR unit2_seq_of_events3 = 10
                OR unit3_seq_of_events3 = 10
           THEN
               1
           WHEN    unit1_seq_of_events4 = 10
                OR unit2_seq_of_events4 = 10
                OR unit3_seq_of_events4 = 10
           THEN
               1
           ELSE
               0
       END    AS cross_median,
       CASE
           WHEN    unit1_seq_of_events1 = 48
                OR unit2_seq_of_events1 = 48
                OR unit3_seq_of_events1 = 48
           THEN
               1
           WHEN    unit1_seq_of_events2 = 48
                OR unit2_seq_of_events3 = 48
                OR unit3_seq_of_events4 = 48
           THEN
               1
           WHEN    unit1_seq_of_events3 = 48
                OR unit2_seq_of_events3 = 48
                OR unit3_seq_of_events3 = 48
           THEN
               1
           WHEN    unit1_seq_of_events4 = 48
                OR unit2_seq_of_events4 = 48
                OR unit3_seq_of_events4 = 48
           THEN
               1
           ELSE
               0
       END    AS gate_or_cable,
       CASE
           WHEN    unit1_seq_of_events1 = 30
                OR unit2_seq_of_events1 = 30
                OR unit3_seq_of_events1 = 30
           THEN
               1
           WHEN    unit1_seq_of_events2 = 30
                OR unit2_seq_of_events3 = 30
                OR unit3_seq_of_events4 = 30
           THEN
               1
           WHEN    unit1_seq_of_events3 = 30
                OR unit2_seq_of_events3 = 30
                OR unit3_seq_of_events3 = 30
           THEN
               1
           WHEN    unit1_seq_of_events4 = 30
                OR unit2_seq_of_events4 = 30
                OR unit3_seq_of_events4 = 30
           THEN
               1
           ELSE
               0
       END    AS cable_guardrail_barrier,
       CASE
           WHEN    unit1_seq_of_events1 = 28
                OR unit2_seq_of_events1 = 28
                OR unit3_seq_of_events1 = 28
           THEN
               1
           WHEN    unit1_seq_of_events2 = 28
                OR unit2_seq_of_events3 = 28
                OR unit3_seq_of_events4 = 28
           THEN
               1
           WHEN    unit1_seq_of_events3 = 28
                OR unit2_seq_of_events3 = 28
                OR unit3_seq_of_events3 = 28
           THEN
               1
           WHEN    unit1_seq_of_events4 = 28
                OR unit2_seq_of_events4 = 28
                OR unit3_seq_of_events4 = 28
           THEN
               1
           ELSE
               0
       END    AS bridge_pier_support,
       CASE
           WHEN    unit1_seq_of_events1 = 5
                OR unit2_seq_of_events1 = 5
                OR unit3_seq_of_events1 = 5
           THEN
               1
           WHEN    unit1_seq_of_events2 = 5
                OR unit2_seq_of_events3 = 5
                OR unit3_seq_of_events4 = 5
           THEN
               1
           WHEN    unit1_seq_of_events3 = 5
                OR unit2_seq_of_events3 = 5
                OR unit3_seq_of_events3 = 5
           THEN
               1
           WHEN    unit1_seq_of_events4 = 5
                OR unit2_seq_of_events4 = 5
                OR unit3_seq_of_events4 = 5
           THEN
               1
           ELSE
               0
       END    AS cargo_equipment_loss_or_shift,
       CASE
           WHEN    unit1_seq_of_events1 = 7
                OR unit2_seq_of_events1 = 7
                OR unit3_seq_of_events1 = 7
           THEN
               1
           WHEN    unit1_seq_of_events2 = 7
                OR unit2_seq_of_events3 = 7
                OR unit3_seq_of_events4 = 7
           THEN
               1
           WHEN    unit1_seq_of_events3 = 7
                OR unit2_seq_of_events3 = 7
                OR unit3_seq_of_events3 = 7
           THEN
               1
           WHEN    unit1_seq_of_events4 = 7
                OR unit2_seq_of_events4 = 7
                OR unit3_seq_of_events4 = 7
           THEN
               1
           ELSE
               0
       END    AS seperation_of_units,
       CASE
           WHEN    unit1_seq_of_events1 = 38
                OR unit2_seq_of_events1 = 38
                OR unit3_seq_of_events1 = 38
           THEN
               1
           WHEN    unit1_seq_of_events2 = 38
                OR unit2_seq_of_events3 = 38
                OR unit3_seq_of_events4 = 38
           THEN
               1
           WHEN    unit1_seq_of_events3 = 38
                OR unit2_seq_of_events3 = 38
                OR unit3_seq_of_events3 = 38
           THEN
               1
           WHEN    unit1_seq_of_events4 = 38
                OR unit2_seq_of_events4 = 38
                OR unit3_seq_of_events4 = 38
           THEN
               1
           ELSE
               0
       END    AS other_traffic_barrier,
       CASE
           WHEN    unit1_seq_of_events1 = 4
                OR unit2_seq_of_events1 = 4
                OR unit3_seq_of_events1 = 4
           THEN
               1
           WHEN    unit1_seq_of_events2 = 4
                OR unit2_seq_of_events3 = 4
                OR unit3_seq_of_events4 = 4
           THEN
               1
           WHEN    unit1_seq_of_events3 = 4
                OR unit2_seq_of_events3 = 4
                OR unit3_seq_of_events3 = 4
           THEN
               1
           WHEN    unit1_seq_of_events4 = 4
                OR unit2_seq_of_events4 = 4
                OR unit3_seq_of_events4 = 4
           THEN
               1
           ELSE
               0
       END    AS jackknife,
       CASE
           WHEN    unit1_seq_of_events1 = 31
                OR unit2_seq_of_events1 = 31
                OR unit3_seq_of_events1 = 31
           THEN
               1
           WHEN    unit1_seq_of_events2 = 31
                OR unit2_seq_of_events3 = 31
                OR unit3_seq_of_events4 = 31
           THEN
               1
           WHEN    unit1_seq_of_events3 = 31
                OR unit2_seq_of_events3 = 31
                OR unit3_seq_of_events3 = 31
           THEN
               1
           WHEN    unit1_seq_of_events4 = 31
                OR unit2_seq_of_events4 = 31
                OR unit3_seq_of_events4 = 31
           THEN
               1
           ELSE
               0
       END    AS culvert,
       CASE
           WHEN    unit1_seq_of_events1 = 43
                OR unit2_seq_of_events1 = 43
                OR unit3_seq_of_events1 = 43
           THEN
               1
           WHEN    unit1_seq_of_events2 = 43
                OR unit2_seq_of_events3 = 43
                OR unit3_seq_of_events4 = 43
           THEN
               1
           WHEN    unit1_seq_of_events3 = 43
                OR unit2_seq_of_events3 = 43
                OR unit3_seq_of_events3 = 43
           THEN
               1
           WHEN    unit1_seq_of_events4 = 43
                OR unit2_seq_of_events4 = 43
                OR unit3_seq_of_events4 = 43
           THEN
               1
           ELSE
               0
       END    AS other_post_pole_support,
       CASE
           WHEN    unit1_seq_of_events1 = 42
                OR unit2_seq_of_events1 = 42
                OR unit3_seq_of_events1 = 42
           THEN
               1
           WHEN    unit1_seq_of_events2 = 42
                OR unit2_seq_of_events3 = 42
                OR unit3_seq_of_events4 = 42
           THEN
               1
           WHEN    unit1_seq_of_events3 = 42
                OR unit2_seq_of_events3 = 42
                OR unit3_seq_of_events3 = 42
           THEN
               1
           WHEN    unit1_seq_of_events4 = 42
                OR unit2_seq_of_events4 = 42
                OR unit3_seq_of_events4 = 42
           THEN
               1
           ELSE
               0
       END    AS traffic_signal_support,
       unit1_precrash_actions_descr,
       unit2_precrash_actions_descr,
       unit3_precrash_actions_descr,
       unit1_precrash_actions,
       unit2_precrash_actions,
       unit3_precrash_actions,
       unit1_seq_of_events1_descr,
       unit2_seq_of_events1_descr,
       unit3_seq_of_events1_descr,
       unit1_seq_of_events1,
       unit2_seq_of_events1,
       unit3_seq_of_events1,
       unit1_seq_of_events2_descr,
       unit2_seq_of_events2_descr,
       unit3_seq_of_events2_descr,
       unit1_seq_of_events2,
       unit2_seq_of_events2,
       unit3_seq_of_events2,
       unit1_seq_of_events3_descr,
       unit2_seq_of_events3_descr,
       unit3_seq_of_events3_descr,
       unit1_seq_of_events3,
       unit2_seq_of_events3,
       unit3_seq_of_events3,
       unit1_seq_of_events4_descr,
       unit2_seq_of_events4_descr,
       unit3_seq_of_events4_descr,
       unit1_seq_of_events4,
       unit2_seq_of_events4,
       unit3_seq_of_events4,
       unit1_direction_of_travel_descr,
       unit2_direction_of_travel_descr,
       unit3_direction_of_travel_descr,
       unit1_direction_of_travel,
       unit2_direction_of_travel,
       unit3_direction_of_travel,
       unit1_unit_type,
       unit1_unit_type_descr,
       unit2_unit_type,
       unit2_unit_type_descr,
       unit3_unit_type,
       unit3_unit_type_descr,
       unit1_extent_of_damage,
       unit1_extent_of_damage_descr,
       unit2_extent_of_damage,
       unit2_extent_of_damage_descr,
       unit3_extent_of_damage,
       unit3_extent_of_damage_descr,
       UNIT1_MOST_DAMAGED_AREA,
       UNIT1_MOST_DAMAGED_AREA_DESCR,
       UNIT2_MOST_DAMAGED_AREA,
       UNIT2_MOST_DAMAGED_AREA_DESCR,
       UNIT3_MOST_DAMAGED_AREA,
       UNIT3_MOST_DAMAGED_AREA_DESCR,
       UNIT1_CNTRIB_CIRCUM_VEHICLE,
       UNIT1_CNTRIB_CIRCUM_VEHICLE_DESCR,
       UNIT2_CNTRIB_CIRCUM_VEHICLE,
       UNIT2_CNTRIB_CIRCUM_VEHICLE_DESCR,
       UNIT3_CNTRIB_CIRCUM_VEHICLE,
       UNIT3_CNTRIB_CIRCUM_VEHICLE_DESCR
  FROM (SELECT mdotid, crashreportid, unit1_direction_of_travel_descr,
               unit2_direction_of_travel_descr, unit3_direction_of_travel_descr,
               unit1_direction_of_travel, unit2_direction_of_travel,
               unit3_direction_of_travel, unit1_precrash_actions_descr,
               unit2_precrash_actions_descr, unit3_precrash_actions_descr,
               unit1_precrash_actions, unit2_precrash_actions, unit3_precrash_actions,
               unit1_most_harmful_event_descr, unit2_most_harmful_event_descr,
               unit3_most_harmful_event_descr, unit1_most_harmful_event,
               unit2_most_harmful_event, unit3_most_harmful_event,
               unit1_seq_of_events1_descr, unit2_seq_of_events1_descr,
               unit3_seq_of_events1_descr, unit1_seq_of_events1, unit2_seq_of_events1,
               unit3_seq_of_events1, unit1_seq_of_events2_descr, unit2_seq_of_events2_descr,
               unit3_seq_of_events2_descr, unit1_seq_of_events2, unit2_seq_of_events2,
               unit3_seq_of_events2, unit1_seq_of_events3_descr, unit2_seq_of_events3_descr,
               unit3_seq_of_events3_descr, unit1_seq_of_events3, unit2_seq_of_events3,
               unit3_seq_of_events3, unit1_seq_of_events4_descr, unit2_seq_of_events4_descr,
               unit3_seq_of_events4_descr, unit1_seq_of_events4, unit2_seq_of_events4,
               unit3_seq_of_events4, unit1_unit_type, unit1_unit_type_descr, unit2_unit_type,
               unit2_unit_type_descr, unit3_unit_type, unit3_unit_type_descr,
               unit1_extent_of_damage, unit1_extent_of_damage_descr, unit2_extent_of_damage,
               unit2_extent_of_damage_descr, unit3_extent_of_damage,
               unit3_extent_of_damage_descr, UNIT1_MOST_DAMAGED_AREA,
               UNIT1_MOST_DAMAGED_AREA_DESCR, UNIT2_MOST_DAMAGED_AREA,
               UNIT2_MOST_DAMAGED_AREA_DESCR, UNIT3_MOST_DAMAGED_AREA,
               UNIT3_MOST_DAMAGED_AREA_DESCR, UNIT1_CNTRIB_CIRCUM_VEHICLE,
               UNIT1_CNTRIB_CIRCUM_VEHICLE_DESCR, UNIT2_CNTRIB_CIRCUM_VEHICLE,
               UNIT2_CNTRIB_CIRCUM_VEHICLE_DESCR, UNIT3_CNTRIB_CIRCUM_VEHICLE,
               UNIT3_CNTRIB_CIRCUM_VEHICLE_DESCR
          FROM (SELECT *
                  FROM (SELECT mdotid, A.crashreportid, direction_of_travel,
                               direction_of_travel_descr, seq_of_events1,
                               seq_of_events1_descr, seq_of_events2, seq_of_events2_descr,
                               seq_of_events3, seq_of_events3_descr, seq_of_events4,
                               seq_of_events4_descr, precrash_actions,
                               precrash_actions_descr, MOST_HARMFUL_EVENT,
                               most_harmful_event_descr, CNTRIB_CIRCUM, CNTRIB_CIRCUM_DESCR,
                               DENSE_RANK () OVER (PARTITION BY mdotid ORDER BY unit_id) AS unit_id,
                               unit_type, unit_type_descr, extent_of_damage,
                               extent_of_damage_descr, MOSTDAMAGEDAREA AS MOST_DAMAGED_AREA,
                               D.DESCRIPTION AS MOST_DAMAGED_AREA_DESCR
                          FROM accident_units  a
                               LEFT OUTER JOIN units@crash c
                                   ON     a.CRASHREPORTID = C.CRASHREPORTID
                                      AND A.UNIT_ID = C.UNITID
                               LEFT OUTER JOIN REFVEHICLEDAMAGEAREA@CRASH D
                                   ON C.MOSTDAMAGEDAREA = D.ID
                         WHERE unit_type <> 24 --and mdotid in (select mdotid from crashsetup)--and mdotid ='2017-40959'
                                              )
                           PIVOT (
                                 MIN (MOST_DAMAGED_AREA) AS MOST_DAMAGED_AREA,
                                 MIN (MOST_DAMAGED_AREA_DESCR) AS MOST_DAMAGED_AREA_DESCR,
                                 MIN (extent_of_damage) AS extent_of_damage,
                                 MIN (extent_of_damage_descr) AS extent_of_damage_descr,
                                 MIN (unit_type) AS unit_type,
                                 MIN (unit_type_descr) AS unit_type_descr,
                                 MIN (direction_of_travel) AS direction_of_travel,
                                 MIN (direction_of_travel_descr) AS direction_of_travel_descr,
                                 MIN (most_harmful_event) AS most_harmful_event,
                                 MIN (most_harmful_event_descr) AS most_harmful_event_descr,
                                 MIN (precrash_actions) AS precrash_actions,
                                 MIN (precrash_actions_descr) AS precrash_actions_descr,
                                 MIN (seq_of_events1) AS seq_of_events1,
                                 MIN (seq_of_events1_descr) AS seq_of_events1_descr,
                                 MIN (seq_of_events2) AS seq_of_events2,
                                 MIN (seq_of_events2_descr) AS seq_of_events2_descr,
                                 MIN (seq_of_events3) AS seq_of_events3,
                                 MIN (seq_of_events3_descr) AS seq_of_events3_descr,
                                 MIN (seq_of_events4) AS seq_of_events4,
                                 MIN (seq_of_events4_descr) AS seq_of_events4_descr,
                                 MIN (CNTRIB_CIRCUM) AS CNTRIB_CIRCUM_VEHICLE,
                                 MIN (CNTRIB_CIRCUM_DESCR) AS CNTRIB_CIRCUM_VEHICLE_DESCR
                                 FOR unit_id
                                 IN (1 AS unit1, 2 AS unit2, 3 AS unit3))));
