CREATE OR REPLACE PACKAGE PKG_DISSOLVE
AS
    FUNCTION F_DISSOLVE_ROUTE (i_where IN NVARCHAR2, i_columns_1 IN NVARCHAR2)
        RETURN dissolveTable;
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2)
        RETURN dissolveTable;
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2)
        RETURN dissolveTable;
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2)
        RETURN dissolveTable;
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2,
                               i_columns_5   IN NVARCHAR2)
        RETURN dissolveTable;
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2,
                               i_columns_5   IN NVARCHAR2,
                               i_columns_6   IN NVARCHAR2)
        RETURN dissolveTable;
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2,
                               i_columns_5   IN NVARCHAR2,
                               i_columns_6   IN NVARCHAR2,
                               i_columns_7   IN NVARCHAR2)
        RETURN dissolveTable;
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2,
                               i_columns_5   IN NVARCHAR2,
                               i_columns_6   IN NVARCHAR2,
                               i_columns_7   IN NVARCHAR2,
                               i_columns_8   IN NVARCHAR2)
        RETURN dissolveTable;
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2,
                               i_columns_5   IN NVARCHAR2,
                               i_columns_6   IN NVARCHAR2,
                               i_columns_7   IN NVARCHAR2,
                               i_columns_8   IN NVARCHAR2,
                               i_columns_9   IN NVARCHAR2)
        RETURN dissolveTable;
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2,
                               i_columns_5   IN NVARCHAR2,
                               i_columns_6   IN NVARCHAR2,
                               i_columns_7   IN NVARCHAR2,
                               i_columns_8   IN NVARCHAR2,
                               i_columns_9   IN NVARCHAR2,
                               i_columns_10   IN NVARCHAR2)
        RETURN dissolveTable;
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2,
                               i_columns_5   IN NVARCHAR2,
                               i_columns_6   IN NVARCHAR2,
                               i_columns_7   IN NVARCHAR2,
                               i_columns_8   IN NVARCHAR2,
                               i_columns_9   IN NVARCHAR2,
                               i_columns_10   IN NVARCHAR2,
                               i_columns_11   IN NVARCHAR2)
        RETURN dissolveTable;    
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2,
                               i_columns_5   IN NVARCHAR2,
                               i_columns_6   IN NVARCHAR2,
                               i_columns_7   IN NVARCHAR2,
                               i_columns_8   IN NVARCHAR2,
                               i_columns_9   IN NVARCHAR2,
                               i_columns_10   IN NVARCHAR2,
                               i_columns_11   IN NVARCHAR2,
                               i_columns_12   IN NVARCHAR2)
        RETURN dissolveTable;     
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2,
                               i_columns_5   IN NVARCHAR2,
                               i_columns_6   IN NVARCHAR2,
                               i_columns_7   IN NVARCHAR2,
                               i_columns_8   IN NVARCHAR2,
                               i_columns_9   IN NVARCHAR2,
                               i_columns_10   IN NVARCHAR2,
                               i_columns_11   IN NVARCHAR2,
                               i_columns_12   IN NVARCHAR2,
                               i_columns_13   IN NVARCHAR2)
        RETURN dissolveTable;
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2,
                               i_columns_5   IN NVARCHAR2,
                               i_columns_6   IN NVARCHAR2,
                               i_columns_7   IN NVARCHAR2,
                               i_columns_8   IN NVARCHAR2,
                               i_columns_9   IN NVARCHAR2,
                               i_columns_10   IN NVARCHAR2,
                               i_columns_11   IN NVARCHAR2,
                               i_columns_12   IN NVARCHAR2,
                               i_columns_13   IN NVARCHAR2,
                               i_columns_14   IN NVARCHAR2)
        RETURN dissolveTable;   
    FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2,
                               i_columns_5   IN NVARCHAR2,
                               i_columns_6   IN NVARCHAR2,
                               i_columns_7   IN NVARCHAR2,
                               i_columns_8   IN NVARCHAR2,
                               i_columns_9   IN NVARCHAR2,
                               i_columns_10   IN NVARCHAR2,
                               i_columns_11   IN NVARCHAR2,
                               i_columns_12   IN NVARCHAR2,
                               i_columns_13   IN NVARCHAR2,
                               i_columns_14   IN NVARCHAR2,
                               i_columns_15   IN NVARCHAR2)
        RETURN dissolveTable;
     FUNCTION F_DISSOLVE_ROUTE (i_where       IN NVARCHAR2,
                               i_columns_1   IN NVARCHAR2,
                               i_columns_2   IN NVARCHAR2,
                               i_columns_3   IN NVARCHAR2,
                               i_columns_4   IN NVARCHAR2,
                               i_columns_5   IN NVARCHAR2,
                               i_columns_6   IN NVARCHAR2,
                               i_columns_7   IN NVARCHAR2,
                               i_columns_8   IN NVARCHAR2,
                               i_columns_9   IN NVARCHAR2,
                               i_columns_10   IN NVARCHAR2,
                               i_columns_11   IN NVARCHAR2,
                               i_columns_12   IN NVARCHAR2,
                               i_columns_13   IN NVARCHAR2,
                               i_columns_14   IN NVARCHAR2,
                               i_columns_15   IN NVARCHAR2,
                               i_columns_16   IN NVARCHAR2)
        RETURN dissolveTable;      
           
END;
/
