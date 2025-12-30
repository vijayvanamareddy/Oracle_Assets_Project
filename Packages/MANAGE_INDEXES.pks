CREATE OR REPLACE PACKAGE MANAGE_INDEXES
IS
/*  This package marks indexes as unusable and rebuilds them
    Indexes are marked unusable before loading large amounts of data
    Indexes are rebuilt after the load
   
    
  01-07-2019  SH - Initial Version
  10-07-2019  SH - Add partitioned indexes
*/  
     PROCEDURE Mark_Indexes_Unusable (v_table IN VARCHAR2);
     PROCEDURE Rebuild_Unusable_Indexes (v_table IN VARCHAR2);
     PROCEDURE MARK_INDEX_PARTITION_UNUSABLE(v_table IN VARCHAR2, v_partition_name IN VARCHAR2);
     end;
/
