/* ================================================================
   PROJECT 8
   SLOWLY CHANGING DIMENSION - THE PROBLEM

   Project:
   Customer Profile History Analysis using Snowflake

   Goal:
   Demonstrate what happens when customer dimension records
   are simply overwritten when customer attributes change.

   BUSINESS SCENARIO:

   Customer 101:
   Hyderabad -> Bengaluru
   Silver   -> Gold

   Customer 103:
   Vijayawada -> Chennai
   Silver     -> Gold

   Customer 104:
   Gold -> Platinum

   ================================================================ */


/* ================================================================
   TASK 1: CREATE SNOWFLAKE DATABASE AND SCHEMA
   ================================================================ */

-- Create warehouse
CREATE OR REPLACE WAREHOUSE CUSTOMER_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

-- Use warehouse
USE WAREHOUSE CUSTOMER_WH;

-- Create database
CREATE OR REPLACE DATABASE CUSTOMER_DB;

-- Use database
USE DATABASE CUSTOMER_DB;

-- Create schema
CREATE OR REPLACE SCHEMA CUSTOMER_SCHEMA;

-- Use schema
USE SCHEMA CUSTOMER_SCHEMA;


/* ================================================================
   TASK 2: CREATE FILE FORMAT
   ================================================================ */

-- File format for CSV files

CREATE OR REPLACE FILE FORMAT CSV_FORMAT
TYPE = 'CSV'
FIELD_DELIMITER = ','
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
SKIP_HEADER = 1
NULL_IF = ('NULL', 'null');


/* ================================================================
   TASK 3: CREATE INTERNAL STAGE
   ================================================================ */

-- Stage is used to hold CSV files before loading them

CREATE OR REPLACE STAGE CUSTOMER_STAGE
FILE_FORMAT = CSV_FORMAT;


/*
   Upload files into the stage:

   customers_initial.csv
   customer_updates.csv

   Example using SnowSQL / CLI:

   PUT file://C:/project/customers_initial.csv
   @CUSTOMER_STAGE;

   PUT file://C:/project/customer_updates.csv
   @CUSTOMER_STAGE;
*/


/* ================================================================
   TASK 4: CREATE INITIAL CUSTOMER DIMENSION
   ================================================================

   DIM_CUSTOMER stores customer information.

   CUSTOMER_KEY = Surrogate Key
   CUSTOMER_ID  = Business/Natural Key
*/


CREATE OR REPLACE TABLE DIM_CUSTOMER
(
    CUSTOMER_KEY NUMBER AUTOINCREMENT,
    CUSTOMER_ID NUMBER,
    CUSTOMER_NAME VARCHAR,
    CITY VARCHAR,
    STATE VARCHAR,
    MEMBERSHIP VARCHAR,
    SEGMENT VARCHAR,

    CONSTRAINT PK_DIM_CUSTOMER
        PRIMARY KEY (CUSTOMER_KEY)
);


/* ================================================================
   TASK 5: CREATE STAGING TABLE
   ================================================================

   We first load the CSV into a staging table.

   Then we load the dimension from staging.
*/


CREATE OR REPLACE TABLE STG_CUSTOMERS_INITIAL
(
    CUSTOMER_ID NUMBER,
    CUSTOMER_NAME VARCHAR,
    CITY VARCHAR,
    STATE VARCHAR,
    MEMBERSHIP VARCHAR,
    SEGMENT VARCHAR
);


/* ================================================================
   TASK 6: LOAD INITIAL CUSTOMER CSV
   ================================================================ */

COPY INTO STG_CUSTOMERS_INITIAL
FROM @CUSTOMER_STAGE/customers_initial.csv
FILE_FORMAT = (FORMAT_NAME = CSV_FORMAT)
ON_ERROR = 'CONTINUE';


/* ================================================================
   CHECK STAGING DATA
   ================================================================ */

SELECT *
FROM STG_CUSTOMERS_INITIAL;



/* ================================================================
   TASK 7: LOAD INITIAL DATA INTO DIM_CUSTOMER
   ================================================================ */

INSERT INTO DIM_CUSTOMER
(
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    SEGMENT
)

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    SEGMENT

FROM STG_CUSTOMERS_INITIAL;


/* ================================================================
   TASK 8: CHECK INITIAL CUSTOMER COUNT
   ================================================================ */

SELECT COUNT(*) AS TOTAL_CUSTOMERS
FROM DIM_CUSTOMER;


/*
   Expected:

   TOTAL_CUSTOMERS
   ----------------
   5
*/


/* ================================================================
   TASK 9: DISPLAY INITIAL CUSTOMER DIMENSION
   ================================================================ */

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    SEGMENT

FROM DIM_CUSTOMER

ORDER BY CUSTOMER_ID;



/* ================================================================
   TASK 10: CREATE CUSTOMER UPDATE STAGING TABLE
   ================================================================ */

CREATE OR REPLACE TABLE CUSTOMER_UPDATES
(
    CUSTOMER_ID NUMBER,
    CUSTOMER_NAME VARCHAR,
    CITY VARCHAR,
    STATE VARCHAR,
    MEMBERSHIP VARCHAR,
    SEGMENT VARCHAR
);


/* ================================================================
   TASK 11: LOAD CUSTOMER UPDATE FILE
   ================================================================ */

COPY INTO CUSTOMER_UPDATES
FROM @CUSTOMER_STAGE/customer_updates.csv
FILE_FORMAT = (FORMAT_NAME = CSV_FORMAT)
ON_ERROR = 'CONTINUE';


/* ================================================================
   CHECK UPDATE DATA
   ================================================================ */

SELECT *
FROM CUSTOMER_UPDATES;


/*
   Expected:

   101 | Amit Sharma | Bengaluru | Karnataka  | Gold     | Premium
   103 | Rahul Verma | Chennai   | Tamil Nadu | Gold     | Premium
   104 | Neha Patel  | Hyderabad | Telangana  | Platinum | Premium
*/


/* ================================================================
   TASK 12: CHECK NUMBER OF UPDATE RECORDS
   ================================================================ */

SELECT COUNT(*) AS RECORDS_RECEIVED
FROM CUSTOMER_UPDATES;


/*
   Expected:

   RECORDS_RECEIVED
   ----------------
   3
*/


/* ================================================================
   TASK 13: IDENTIFY CHANGED CUSTOMERS
   ================================================================

   Compare:

   DIM_CUSTOMER
          VS
   CUSTOMER_UPDATES

   We check:

   CITY
   STATE
   MEMBERSHIP
   SEGMENT
*/


SELECT

    D.CUSTOMER_ID,

    D.CITY AS OLD_CITY,
    U.CITY AS NEW_CITY,

    D.STATE AS OLD_STATE,
    U.STATE AS NEW_STATE,

    D.MEMBERSHIP AS OLD_MEMBERSHIP,
    U.MEMBERSHIP AS NEW_MEMBERSHIP,

    D.SEGMENT AS OLD_SEGMENT,
    U.SEGMENT AS NEW_SEGMENT

FROM DIM_CUSTOMER D

JOIN CUSTOMER_UPDATES U
    ON D.CUSTOMER_ID = U.CUSTOMER_ID

WHERE
       NVL(D.CITY, '') <> NVL(U.CITY, '')
    OR NVL(D.STATE, '') <> NVL(U.STATE, '')
    OR NVL(D.MEMBERSHIP, '') <> NVL(U.MEMBERSHIP, '')
    OR NVL(D.SEGMENT, '') <> NVL(U.SEGMENT, '')

ORDER BY D.CUSTOMER_ID;


/*
   Expected:

   CUSTOMER_ID | OLD_CITY    | NEW_CITY   | OLD_MEMBERSHIP | NEW_MEMBERSHIP
   -------------------------------------------------------------------------
   101         | Hyderabad   | Bengaluru  | Silver         | Gold
   103         | Vijayawada  | Chennai    | Silver         | Gold
   104         | Hyderabad   | Hyderabad  | Gold           | Platinum
*/


/* ================================================================
   TASK 14: IDENTIFY ATTRIBUTE-LEVEL CHANGES
   ================================================================

   Instead of simply saying:

       Customer 101 changed

   we want to know:

       Customer 101
       CITY changed
       STATE changed
       MEMBERSHIP changed

*/


/* -----------------------------
   CITY CHANGES
   ----------------------------- */

SELECT
    D.CUSTOMER_ID,
    'CITY' AS ATTRIBUTE,
    D.CITY AS OLD_VALUE,
    U.CITY AS NEW_VALUE

FROM DIM_CUSTOMER D

JOIN CUSTOMER_UPDATES U
    ON D.CUSTOMER_ID = U.CUSTOMER_ID

WHERE NVL(D.CITY, '') <> NVL(U.CITY, '')


UNION ALL


/* -----------------------------
   STATE CHANGES
   ----------------------------- */

SELECT
    D.CUSTOMER_ID,
    'STATE' AS ATTRIBUTE,
    D.STATE AS OLD_VALUE,
    U.STATE AS NEW_VALUE

FROM DIM_CUSTOMER D

JOIN CUSTOMER_UPDATES U
    ON D.CUSTOMER_ID = U.CUSTOMER_ID

WHERE NVL(D.STATE, '') <> NVL(U.STATE, '')


UNION ALL


/* -----------------------------
   MEMBERSHIP CHANGES
   ----------------------------- */

SELECT
    D.CUSTOMER_ID,
    'MEMBERSHIP' AS ATTRIBUTE,
    D.MEMBERSHIP AS OLD_VALUE,
    U.MEMBERSHIP AS NEW_VALUE

FROM DIM_CUSTOMER D

JOIN CUSTOMER_UPDATES U
    ON D.CUSTOMER_ID = U.CUSTOMER_ID

WHERE NVL(D.MEMBERSHIP, '') <> NVL(U.MEMBERSHIP, '')


UNION ALL


/* -----------------------------
   SEGMENT CHANGES
   ----------------------------- */

SELECT
    D.CUSTOMER_ID,
    'SEGMENT' AS ATTRIBUTE,
    D.SEGMENT AS OLD_VALUE,
    U.SEGMENT AS NEW_VALUE

FROM DIM_CUSTOMER D

JOIN CUSTOMER_UPDATES U
    ON D.CUSTOMER_ID = U.CUSTOMER_ID

WHERE NVL(D.SEGMENT, '') <> NVL(U.SEGMENT, '')

ORDER BY CUSTOMER_ID, ATTRIBUTE;


/*
   Expected:

   101 | CITY       | Hyderabad       | Bengaluru
   101 | STATE      | Telangana       | Karnataka
   101 | MEMBERSHIP | Silver          | Gold

   103 | CITY       | Vijayawada      | Chennai
   103 | STATE      | Andhra Pradesh  | Tamil Nadu
   103 | MEMBERSHIP | Silver          | Gold

   104 | MEMBERSHIP | Gold            | Platinum
*/


/* ================================================================
   TASK 15: DEMONSTRATE THE SCD PROBLEM
   ================================================================

   The company currently overwrites the old dimension
   record with the new values.

   This is the problem we want to demonstrate.

   BEFORE:

   Customer 101
   Hyderabad
   Telangana
   Silver

   AFTER UPDATE:

   Customer 101
   Bengaluru
   Karnataka
   Gold

   The old information disappears.
*/


/* ================================================================
   TASK 16: OVERWRITE EXISTING CUSTOMER RECORDS
   ================================================================

   MERGE is used to update existing customers.

   NOTE:
   This is NOT SCD Type 2.

   This demonstrates the historical-data-loss problem.
*/


MERGE INTO DIM_CUSTOMER D

USING CUSTOMER_UPDATES U

ON D.CUSTOMER_ID = U.CUSTOMER_ID

WHEN MATCHED THEN

UPDATE SET

    D.CUSTOMER_NAME = U.CUSTOMER_NAME,
    D.CITY = U.CITY,
    D.STATE = U.STATE,
    D.MEMBERSHIP = U.MEMBERSHIP,
    D.SEGMENT = U.SEGMENT;


/* ================================================================
   TASK 17: DISPLAY UPDATED DIMENSION
   ================================================================ */

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    SEGMENT

FROM DIM_CUSTOMER

ORDER BY CUSTOMER_ID;


/*
   Expected:

   CUSTOMER_ID | CUSTOMER_NAME | CITY       | STATE        | MEMBERSHIP
   ---------------------------------------------------------------------
   101         | Amit Sharma   | Bengaluru  | Karnataka    | Gold
   102         | Priya Reddy   | Warangal   | Telangana    | Gold
   103         | Rahul Verma   | Chennai    | Tamil Nadu   | Gold
   104         | Neha Patel    | Hyderabad  | Telangana    | Platinum
   105         | Arjun Gupta   | Nagpur     | Maharashtra  | Bronze
*/


/* ================================================================
   TASK 18: DEMONSTRATE HISTORICAL DATA LOSS
   ================================================================

   Now try to find Customer 101's old city.

   The current dimension only contains:

       Bengaluru
       Karnataka
       Gold

   Hyderabad, Telangana and Silver are gone.
*/


SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP

FROM DIM_CUSTOMER

WHERE CUSTOMER_ID = 101;


/*
   Current result:

   101 | Amit Sharma | Bengaluru | Karnataka | Gold


   But the original information was:

   101 | Amit Sharma | Hyderabad | Telangana | Silver


   Therefore:

   Historical City       -> LOST
   Historical State      -> LOST
   Historical Membership -> LOST
*/


/* ================================================================
   TASK 19: BUSINESS IMPACT ANALYSIS
   ================================================================ */


/*
   Customer 101

   ORIGINAL:
   City       = Hyderabad
   State      = Telangana
   Membership = Silver

   CURRENT:
   City       = Bengaluru
   State      = Karnataka
   Membership = Gold


   After overwriting:

   Hyderabad -> LOST
   Telangana -> LOST
   Silver    -> LOST
*/


/* ================================================================
   TASK 20: FINAL PROOF OF THE SCD PROBLEM
   ================================================================

   Question:

   Can we find where Customer 101 lived before?

   Answer:

   NO.

   Because DIM_CUSTOMER contains only the latest values.

   This is exactly the Slowly Changing Dimension problem.
*/


SELECT
    CUSTOMER_ID,
    CITY AS CURRENT_CITY,
    STATE AS CURRENT_STATE,
    MEMBERSHIP AS CURRENT_MEMBERSHIP

FROM DIM_CUSTOMER

WHERE CUSTOMER_ID = 101;


/*
   RESULT:

   CUSTOMER_ID | CURRENT_CITY | CURRENT_STATE | CURRENT_MEMBERSHIP
   ----------------------------------------------------------------
   101         | Bengaluru    | Karnataka     | Gold


   We cannot retrieve:

       Hyderabad
       Telangana
       Silver

   because those values were overwritten.
*/


/* ================================================================
   PROJECT CONCLUSION
   ================================================================

   The project demonstrates:

   1. Customer attributes can change over time.

   2. We load the initial customer dimension.

   3. We receive a customer update file.

   4. We compare old and new values.

   5. We identify changed customers.

   6. We identify which attributes changed.

   7. We overwrite the dimension using UPDATE/MERGE.

   8. The old values disappear.

   9. Historical analysis becomes impossible.

   10. This demonstrates the SCD problem.

   ================================================================

   IMPORTANT INTERVIEW LINE:

   "If we simply overwrite a changed dimension record,
   the current value is preserved but the historical value
   is lost. Therefore, if the business requires historical
   tracking, we need an appropriate Slowly Changing Dimension
   strategy such as SCD Type 2."

   ================================================================ */