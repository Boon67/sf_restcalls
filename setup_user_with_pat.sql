-- ============================================================================
-- Snowflake User Setup with PAT Token Authentication
-- ============================================================================
-- This script creates a user account configured for PAT (Personal Access Token)
-- authentication with default database, schema, and warehouse settings.
--
-- Prerequisites:
-- 1. Must be executed by an account administrator or user with USERADMIN role
-- 2. Target database, schema, and warehouse must already exist
-- 3. Appropriate roles must be created and granted necessary privileges
--
-- Usage:
-- 1. Replace placeholder values with actual names
-- 2. Execute each section in order
-- 3. Generate PAT token for the user after creation
-- ============================================================================

-- Set context (run as administrator)
USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- SECTION 1: Create Database, Schema, and Warehouse (if they don't exist)
-- ============================================================================

-- Create database
CREATE DATABASE IF NOT EXISTS ANALYTICS_DB
    COMMENT = 'Database for analytics operations';

-- Create schema
CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.PUBLIC
    COMMENT = 'Default schema for analytics operations';

-- Create warehouse
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
    WITH 
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    SCALING_POLICY = 'STANDARD'
    COMMENT = 'Default compute warehouse for analytics';

-- ============================================================================
-- SECTION 2: Create Custom Roles
-- ============================================================================

-- Create role for analytics users
CREATE ROLE IF NOT EXISTS ANALYTICS_ROLE
    COMMENT = 'Role for analytics users with access to analytics database';

-- Create role for stored procedure execution
CREATE ROLE IF NOT EXISTS SP_EXECUTOR_ROLE
    COMMENT = 'Role for executing stored procedures';

-- ============================================================================
-- SECTION 3: Grant Privileges to Roles
-- ============================================================================

-- Grant warehouse usage
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE ANALYTICS_ROLE;
GRANT OPERATE ON WAREHOUSE COMPUTE_WH TO ROLE ANALYTICS_ROLE;

-- Grant database and schema access
GRANT USAGE ON DATABASE ANALYTICS_DB TO ROLE ANALYTICS_ROLE;
GRANT USAGE ON SCHEMA ANALYTICS_DB.PUBLIC TO ROLE ANALYTICS_ROLE;

-- Grant table privileges (adjust as needed)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ANALYTICS_DB.PUBLIC TO ROLE ANALYTICS_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA ANALYTICS_DB.PUBLIC TO ROLE ANALYTICS_ROLE;

-- Grant stored procedure privileges
GRANT USAGE ON ALL PROCEDURES IN SCHEMA ANALYTICS_DB.PUBLIC TO ROLE ANALYTICS_ROLE;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA ANALYTICS_DB.PUBLIC TO ROLE ANALYTICS_ROLE;

-- Grant specific procedure execution rights to SP_EXECUTOR_ROLE
GRANT USAGE ON ALL PROCEDURES IN SCHEMA ANALYTICS_DB.PUBLIC TO ROLE SP_EXECUTOR_ROLE;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA ANALYTICS_DB.PUBLIC TO ROLE SP_EXECUTOR_ROLE;

-- Grant warehouse usage to SP_EXECUTOR_ROLE
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE SP_EXECUTOR_ROLE;

-- Grant database and schema access to SP_EXECUTOR_ROLE
GRANT USAGE ON DATABASE ANALYTICS_DB TO ROLE SP_EXECUTOR_ROLE;
GRANT USAGE ON SCHEMA ANALYTICS_DB.PUBLIC TO ROLE SP_EXECUTOR_ROLE;

-- ============================================================================
-- SECTION 4: Create User Account
-- ============================================================================

-- Create user with PAT token authentication enabled
CREATE USER IF NOT EXISTS sf_api_user
    PASSWORD = 'TempPassword123!'  -- Will be changed after PAT setup
    LOGIN_NAME = 'sf_api_user'
    DISPLAY_NAME = 'Snowflake API User'
    FIRST_NAME = 'API'
    LAST_NAME = 'User'
    EMAIL = 'api-user@yourcompany.com'
    
    -- Set default context
    DEFAULT_WAREHOUSE = 'COMPUTE_WH'
    DEFAULT_DATABASE = 'ANALYTICS_DB'
    DEFAULT_SCHEMA = 'PUBLIC'
    DEFAULT_ROLE = 'ANALYTICS_ROLE'
    
    -- Configure for API access
    MUST_CHANGE_PASSWORD = FALSE
    DISABLED = FALSE
    
    -- Optional: Set session parameters
    DEFAULT_NAMESPACE = 'ANALYTICS_DB.PUBLIC'
    
    COMMENT = 'User account for API access with PAT token authentication';

-- ============================================================================
-- SECTION 5: Grant Roles to User
-- ============================================================================

-- Grant primary role
GRANT ROLE ANALYTICS_ROLE TO USER sf_api_user;

-- Grant stored procedure execution role
GRANT ROLE SP_EXECUTOR_ROLE TO USER sf_api_user;

-- Set default role
ALTER USER sf_api_user SET DEFAULT_ROLE = 'ANALYTICS_ROLE';

-- ============================================================================
-- SECTION 6: Create Example Stored Procedure
-- ============================================================================

-- Switch to the target database and schema
USE DATABASE ANALYTICS_DB;
USE SCHEMA PUBLIC;
USE WAREHOUSE COMPUTE_WH;

-- Create the sp_example stored procedure that the library expects
CREATE OR REPLACE PROCEDURE sp_example()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    RETURN 'Hello from sp_example! Current timestamp: ' || CURRENT_TIMESTAMP()::STRING;
END;
$$
COMMENT = 'Example stored procedure for testing API calls';

-- Create a more complex example procedure with parameters
CREATE OR REPLACE PROCEDURE sp_example_with_params(
    input_text STRING,
    input_number NUMBER,
    input_boolean BOOLEAN
)
RETURNS TABLE (
    result_text STRING,
    result_number NUMBER,
    result_boolean BOOLEAN,
    timestamp_created TIMESTAMP_NTZ
)
LANGUAGE SQL
AS
$$
BEGIN
    LET result_set RESULTSET := (
        SELECT 
            input_text AS result_text,
            input_number * 2 AS result_number,
            NOT input_boolean AS result_boolean,
            CURRENT_TIMESTAMP() AS timestamp_created
    );
    RETURN TABLE(result_set);
END;
$$
COMMENT = 'Example stored procedure with parameters for testing API calls';

-- Create a procedure that returns sample data
CREATE OR REPLACE PROCEDURE sp_get_sample_data()
RETURNS TABLE (
    id NUMBER,
    name STRING,
    value NUMBER,
    created_date DATE
)
LANGUAGE SQL
AS
$$
BEGIN
    LET result_set RESULTSET := (
        SELECT 
            ROW_NUMBER() OVER (ORDER BY 1) AS id,
            'Sample_' || ROW_NUMBER() OVER (ORDER BY 1) AS name,
            UNIFORM(1, 100, RANDOM()) AS value,
            CURRENT_DATE() AS created_date
        FROM TABLE(GENERATOR(ROWCOUNT => 5))
    );
    RETURN TABLE(result_set);
END;
$$
COMMENT = 'Returns sample data for testing';

-- Grant execute permissions on the procedures
GRANT USAGE ON PROCEDURE sp_example() TO ROLE ANALYTICS_ROLE;
GRANT USAGE ON PROCEDURE sp_example_with_params(STRING, NUMBER, BOOLEAN) TO ROLE ANALYTICS_ROLE;
GRANT USAGE ON PROCEDURE sp_get_sample_data() TO ROLE ANALYTICS_ROLE;

GRANT USAGE ON PROCEDURE sp_example() TO ROLE SP_EXECUTOR_ROLE;
GRANT USAGE ON PROCEDURE sp_example_with_params(STRING, NUMBER, BOOLEAN) TO ROLE SP_EXECUTOR_ROLE;
GRANT USAGE ON PROCEDURE sp_get_sample_data() TO ROLE SP_EXECUTOR_ROLE;

-- ============================================================================
-- SECTION 7: Verification Queries
-- ============================================================================

-- Verify user creation
SHOW USERS LIKE 'sf_api_user';

-- Verify role grants
SHOW GRANTS TO USER sf_api_user;

-- Verify user defaults
DESC USER sf_api_user;

-- Verify procedures exist
SHOW PROCEDURES IN SCHEMA ANALYTICS_DB.PUBLIC;

-- ============================================================================
-- SECTION 8: PAT Token Setup Instructions
-- ============================================================================

/*
IMPORTANT: After running this script, you need to generate a PAT token:

1. Log in as the sf_api_user (or have an admin do this)
2. Go to Snowflake Web UI > User Preferences > Personal Access Tokens
3. Click "Generate Token"
4. Provide a name for the token (e.g., "API_Access_Token")
5. Set expiration date (recommended: 90 days or less)
6. Click "Generate"
7. Copy the token immediately (it won't be shown again)

Alternatively, use SQL to create the token (as ACCOUNTADMIN):

-- Create PAT token for the user
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE PERSONAL ACCESS TOKEN sf_api_user_token
    FOR USER sf_api_user
    EXPIRES = DATEADD(DAY, 90, CURRENT_DATE())
    COMMENT = 'PAT token for API access';

-- To view token details (token value is only shown once)
SHOW PERSONAL ACCESS TOKENS FOR USER sf_api_user;
*/

-- ============================================================================
-- SECTION 9: Environment Configuration
-- ============================================================================

/*
After generating the PAT token, configure your environment:

export SNOWFLAKE_ACCOUNT="your-account.snowflakecomputing.com"
export SNOWFLAKE_USERNAME="sf_api_user"
export SNOWFLAKE_TOKEN="your-generated-pat-token"
export SNOWFLAKE_DATABASE="ANALYTICS_DB"
export SNOWFLAKE_SCHEMA="PUBLIC"
export SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
export SNOWFLAKE_ROLE="ANALYTICS_ROLE"

Then test with:
./snowflake_curl_script.sh sp_example
./snowflake_curl_script.sh sp_example_with_params "test,42,true"
./snowflake_curl_script.sh sp_get_sample_data
*/

-- ============================================================================
-- SECTION 10: Testing Queries
-- ============================================================================

-- Test the stored procedures manually
-- (Execute these as the sf_api_user to verify permissions)

/*
-- Switch to the user context for testing
USE ROLE ANALYTICS_ROLE;
USE DATABASE ANALYTICS_DB;
USE SCHEMA PUBLIC;
USE WAREHOUSE COMPUTE_WH;

-- Test the procedures
CALL sp_example();
CALL sp_example_with_params('test', 42, TRUE);
CALL sp_get_sample_data();

-- Verify current context
SELECT 
    CURRENT_USER() AS current_user,
    CURRENT_ROLE() AS current_role,
    CURRENT_DATABASE() AS current_database,
    CURRENT_SCHEMA() AS current_schema,
    CURRENT_WAREHOUSE() AS current_warehouse;
*/

-- ============================================================================
-- CLEANUP SECTION (OPTIONAL - USE WITH CAUTION)
-- ============================================================================

/*
-- Uncomment to clean up resources (USE WITH CAUTION!)

-- Drop procedures
-- DROP PROCEDURE IF EXISTS sp_example();
-- DROP PROCEDURE IF EXISTS sp_example_with_params(STRING, NUMBER, BOOLEAN);
-- DROP PROCEDURE IF EXISTS sp_get_sample_data();

-- Revoke roles from user
-- REVOKE ROLE ANALYTICS_ROLE FROM USER sf_api_user;
-- REVOKE ROLE SP_EXECUTOR_ROLE FROM USER sf_api_user;

-- Drop user
-- DROP USER IF EXISTS sf_api_user;

-- Drop roles
-- DROP ROLE IF EXISTS ANALYTICS_ROLE;
-- DROP ROLE IF EXISTS SP_EXECUTOR_ROLE;

-- Drop warehouse, schema, database (if desired)
-- DROP WAREHOUSE IF EXISTS COMPUTE_WH;
-- DROP SCHEMA IF EXISTS ANALYTICS_DB.PUBLIC;
-- DROP DATABASE IF EXISTS ANALYTICS_DB;
*/

-- End of script
SELECT 'User setup completed successfully!' AS status;
