-- Fix TO_DATE type error by casting NUMBER column to VARCHAR and correcting format mask
-- Co-authored with CoCo
-- NAME : KMK CASE STUDY SETUP
-- VERSION: 1.0
-- OWNER: BISWAJIT NAYAK
-- DATE: 23/-7/2026

------------------------------------------------------------------------------------------------------------------------
------------------------------------CREATING THE DATABASE AND SCHEMA OBJECTS -------------------------------------------
------------------------------------------------------------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

---------------------------------------------------------------------------
-- CREATING THE DATABASE

CREATE DATABASE IF NOT EXISTS KMK_CASE_STUDY;

-----------------------------------------------------------------------------
-- CREATING THE WAREHOUSE

CREATE SCHEMA IF NOT EXISTS KMK_CASE_STUDY.KMK_STAGING;
CREATE SCHEMA IF NOT EXISTS KMK_CASE_STUDY.KMK_CURATED;


-------------------------------------------------------------------------
-- CREATING THE WAREHOUSE
CREATE WAREHOUSE IF NOT EXISTS KMK_CASE_STUDY_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 120
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Wareshouse to be used for KMK case study on Tableau Dashboard';

-------------------------------------------------------------------
-- SETTING UP THE CONTEXT 
USE DATABASE KMK_CASE_STUDY;
USE SCHEMA KMK_STAGING;
USE WAREHOUSE KMK_CASE_STUDY_WH;

------------------------------------------------------------------------------------------------------------------------
------------------------------------CREATING THE TABLES USING INFER SCHEMA & DATA LOAD----------------------------------
------------------------------------------------------------------------------------------------------------------------

    -------------------------------------------1. CREATING THE FILE FORMAT
    
    CREATE OR REPLACE FILE FORMAT KMK_CASE_STUDY.KMK_STAGING.CSV_FF
    TYPE = CSV
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    -- SKIP_HEADER = 1
    PARSE_HEADER = TRUE
    NULL_IF = ('NULL','','null')
    EMPTY_FIELD_AS_NULL = TRUE
    ;

    DESCRIBE FILE FORMAT KMK_CASE_STUDY.KMK_STAGING.CSV_FF;
    
    -------------------------------------------2. CREATING A STAGE
    
    CREATE OR REPLACE STAGE KMK_CASE_STUDY.KMK_STAGING.KMK_STAGE
    FILE_FORMAT = KMK_CASE_STUDY.KMK_STAGING.CSV_FF;
    
    ----- AT THIS MOMENT NO FILE ARE THERE IN STAGING, HENCE THE LIST WON'T SHOW ANY FILE LIST. USE THE SNOWui TO LOAD THE DATA INTO STAGE WHICH WAS CREATED THE ABOVE STEP AND RUN BELOW LINE TO SEE THE LIST OF FILES. 

    LIST @KMK_CASE_STUDY.KMK_STAGING.KMK_STAGE;

    --------------------------------------------3. CREATING THE TABLE USING INFER SCHEMA

    CREATE OR REPLACE TABLE KMK_CASE_STUDY.KMK_STAGING.SALES
    USING TEMPLATE(
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
        FROM TABLE(INFER_SCHEMA(LOCATION => '@KMK_CASE_STUDY.KMK_STAGING.KMK_STAGE/sales_data.csv',FILE_FORMAT =>       'KMK_CASE_STUDY.KMK_STAGING.CSV_FF'))
        );
    
    SELECT * FROM KMK_CASE_STUDY.KMK_STAGING.SALES;

    --------------------------------------------------------------------------------------------------------

    CREATE OR REPLACE TABLE KMK_CASE_STUDY.KMK_STAGING.CALLS
    USING TEMPLATE(
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
        FROM TABLE(INFER_SCHEMA(LOCATION => '@KMK_CASE_STUDY.KMK_STAGING.KMK_STAGE/calls_data.csv',FILE_FORMAT => 'KMK_CASE_STUDY.KMK_STAGING.CSV_FF'))
        );

    SELECT * FROM KMK_CASE_STUDY.KMK_STAGING.CALLS;
    -----------------------------------------------------------------------------------------------------------

    CREATE OR REPLACE TABLE KMK_CASE_STUDY.KMK_STAGING.PATIENTS
    USING TEMPLATE(
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
        FROM TABLE(INFER_SCHEMA(LOCATION => '@KMK_CASE_STUDY.KMK_STAGING.KMK_STAGE/patients_data.csv',FILE_FORMAT => 'KMK_CASE_STUDY.KMK_STAGING.CSV_FF'))
        );

    SELECT * FROM KMK_CASE_STUDY.KMK_STAGING.PATIENTS;
    -----------------------------------------------------------------------------------------------------------------

    ------4. LOADING THE DATA INTO EACH TABLE USING COPY COMMAND

    COPY INTO KMK_CASE_STUDY.KMK_STAGING.SALES
    FROM '@KMK_CASE_STUDY.KMK_STAGING.KMK_STAGE/sales_data.csv'
    FILE_FORMAT = (
    FORMAT_NAME = KMK_CASE_STUDY.KMK_STAGING.CSV_FF
    )
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;


    COPY INTO KMK_CASE_STUDY.KMK_STAGING.CALLS
    FROM '@KMK_CASE_STUDY.KMK_STAGING.KMK_STAGE/calls_data.csv'
    FILE_FORMAT = (
    FORMAT_NAME = KMK_CASE_STUDY.KMK_STAGING.CSV_FF
    )
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;


    COPY INTO KMK_CASE_STUDY.KMK_STAGING.PATIENTS
    FROM '@KMK_CASE_STUDY.KMK_STAGING.KMK_STAGE/patients_data.csv'
    FILE_FORMAT = (
    FORMAT_NAME = KMK_CASE_STUDY.KMK_STAGING.CSV_FF
    )
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;


------------------------------------------------------------------------------------------------------------------------
------------------------------------CREATING THE TABLES IN CURATED LAYER APPLYING THE TRANSFORMATIONS ------------------
------------------------------------------------------------------------------------------------------------------------

SELECT * FROM KMK_CASE_STUDY.KMK_STAGING.SALES;


CREATE OR REPLACE TABLE KMK_CASE_STUDY.KMK_CURATED.SALES AS
SELECT 
"Territory_Name" AS TERRITORY_NAME,
"Month" AS MONTH_SALES,
TO_DATE("Month"::VARCHAR, 'YYYYMM') AS FINAL_MONTH_SALES,
"Product" AS PRODUCT,
"Actual_Sales" AS ACTUAL_SALES,
"Target_Sales" AS TARGET_SALES
FROM KMK_CASE_STUDY.KMK_STAGING.SALES;



----------------------------------------------------------------------------

SELECT * FROM KMK_CASE_STUDY.KMK_STAGING.CALLS;


CREATE OR REPLACE TABLE KMK_CASE_STUDY.KMK_CURATED.CALLS AS

SELECT
   "Rep_ID" AS REP_ID,
   "Territory_Name" AS TERRITORY_NAME,
   "HCP_Specialty" AS HCP_SPECIALTY,
    RIGHT(MONTH_NAME,8) AS CALLS_MONTH,
    TO_DATE(REPLACE(REPLACE(MONTH_NAME, 'Calls_Completed_', ''), '_', ' '), 'MON YYYY') AS FINAL_CALLS_MONTH,
    "Calls_Planned_per_month" AS CALLS_PLANNED_PER_MONTH,
    COMPLETED_CALLS
FROM(
SELECT * FROM KMK_CASE_STUDY.KMK_STAGING.CALLS
UNPIVOT
(COMPLETED_CALLS FOR MONTH_NAME IN
("Calls_Completed_Jan_2023",
"Calls_Completed_Feb_2023",
"Calls_Completed_Mar_2023",
"Calls_Completed_Apr_2023",
"Calls_Completed_May_2023",
"Calls_Completed_Jun_2023",
"Calls_Completed_Jul_2023",
"Calls_Completed_Aug_2023",
"Calls_Completed_Sep_2023",
"Calls_Completed_Oct_2023",
"Calls_Completed_Nov_2023",
"Calls_Completed_Dec_2023")
));

-------------------------------------------------------------------------------------------
SELECT * FROM KMK_CASE_STUDY.KMK_STAGING.PATIENTS;

CREATE OR REPLACE TABLE KMK_CASE_STUDY.KMK_CURATED.PATIENTS AS

SELECT
"Month" AS MONTH_PATIENTS,
TO_DATE("Month", 'YYYY-MM') AS FINAL_MONTH_PATIENTS,
"New_Patients" AS NEW_PATIENTS,
"Continuing_Patients" AS CONTINUING_PATIENTS,
"Discontinuations" AS DISCONTINUATIONS
FROM KMK_CASE_STUDY.KMK_STAGING.PATIENTS;



------------------------------------------------------------------------------------------------------------------------
-----------------------------------FINAL TABLES FOR TABLEAU ------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

SELECT * FROM KMK_CASE_STUDY.KMK_CURATED.SALES;
SELECT * FROM KMK_CASE_STUDY.KMK_CURATED.CALLS;
SELECT * FROM KMK_CASE_STUDY.KMK_CURATED.PATIENTS;

