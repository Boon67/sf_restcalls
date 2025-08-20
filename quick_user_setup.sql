-- ============================================================================
-- Quick Snowflake User Setup for PAT Token Authentication
-- ============================================================================
-- Simplified script for quick user creation with PAT token support
-- Execute as ACCOUNTADMIN or user with appropriate privileges
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Create resources if they don't exist
CREATE DATABASE IF NOT EXISTS ANALYTICS_DB;
CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.PUBLIC;
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH WITH WAREHOUSE_SIZE = 'X-SMALL' AUTO_SUSPEND = 300;

-- Create role
CREATE ROLE IF NOT EXISTS API_USER_ROLE;

-- Grant basic privileges
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE API_USER_ROLE;
GRANT USAGE ON DATABASE ANALYTICS_DB TO ROLE API_USER_ROLE;
GRANT USAGE ON SCHEMA ANALYTICS_DB.PUBLIC TO ROLE API_USER_ROLE;
GRANT ALL PRIVILEGES ON SCHEMA ANALYTICS_DB.PUBLIC TO ROLE API_USER_ROLE;

-- Create user
CREATE USER IF NOT EXISTS sf_api_user
    PASSWORD = 'TempPassword123!'
    DEFAULT_WAREHOUSE = 'COMPUTE_WH'
    DEFAULT_DATABASE = 'ANALYTICS_DB'
    DEFAULT_SCHEMA = 'PUBLIC'
    DEFAULT_ROLE = 'API_USER_ROLE'
    MUST_CHANGE_PASSWORD = FALSE;

-- Grant role to user
GRANT ROLE API_USER_ROLE TO USER sf_api_user;

-- Create sp_example procedure
USE DATABASE ANALYTICS_DB;
USE SCHEMA PUBLIC;

CREATE OR REPLACE PROCEDURE sp_example()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    RETURN 'Hello from sp_example! Current timestamp: ' || CURRENT_TIMESTAMP()::STRING;
END;
$$;

-- Grant procedure access
GRANT USAGE ON PROCEDURE sp_example() TO ROLE API_USER_ROLE;

-- Show results
SELECT 'Quick setup completed! Now generate PAT token for sf_api_user' AS status;
