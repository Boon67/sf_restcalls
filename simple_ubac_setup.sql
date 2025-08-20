-- ============================================================================
-- Simple User-Based Access Control (UBAC) Setup
-- ============================================================================
-- Simplified UBAC implementation for basic access control needs
-- Execute as ACCOUNTADMIN
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Create UBAC database and schema
CREATE DATABASE IF NOT EXISTS UBAC_DB;
CREATE SCHEMA IF NOT EXISTS UBAC_DB.ACCESS_CONTROL;

USE DATABASE UBAC_DB;
USE SCHEMA ACCESS_CONTROL;

-- ============================================================================
-- Simple Access Control Tables
-- ============================================================================

-- User access permissions table
CREATE TABLE IF NOT EXISTS USER_ACCESS_CONTROL (
    USER_NAME STRING NOT NULL,
    RESOURCE_TYPE STRING NOT NULL, -- PROCEDURE, TABLE, DATABASE, etc.
    RESOURCE_NAME STRING NOT NULL,
    ACCESS_LEVEL STRING NOT NULL, -- READ, WRITE, EXECUTE, ADMIN
    GRANTED_BY STRING DEFAULT CURRENT_USER(),
    GRANTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    EXPIRES_AT TIMESTAMP_NTZ,
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (USER_NAME, RESOURCE_TYPE, RESOURCE_NAME, ACCESS_LEVEL)
);

-- Simple audit log
CREATE TABLE IF NOT EXISTS SIMPLE_ACCESS_LOG (
    LOG_ID NUMBER IDENTITY,
    USER_NAME STRING NOT NULL,
    RESOURCE_NAME STRING NOT NULL,
    ACTION STRING NOT NULL,
    ACCESS_RESULT STRING NOT NULL, -- GRANTED, DENIED
    TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- Core UBAC Procedures
-- ============================================================================

-- Simple access check procedure
CREATE OR REPLACE PROCEDURE SP_CHECK_ACCESS(
    P_USER_NAME STRING,
    P_RESOURCE_NAME STRING,
    P_ACCESS_LEVEL STRING
)
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
DECLARE
    access_count INTEGER;
    has_access BOOLEAN DEFAULT FALSE;
BEGIN
    -- Check if user has required access
    SELECT COUNT(*) INTO access_count
    FROM USER_ACCESS_CONTROL
    WHERE USER_NAME = P_USER_NAME
      AND RESOURCE_NAME = P_RESOURCE_NAME
      AND ACCESS_LEVEL = P_ACCESS_LEVEL
      AND IS_ACTIVE = TRUE
      AND (EXPIRES_AT IS NULL OR EXPIRES_AT > CURRENT_TIMESTAMP());
    
    SET has_access = (access_count > 0);
    
    -- Log the access attempt
    INSERT INTO SIMPLE_ACCESS_LOG (USER_NAME, RESOURCE_NAME, ACTION, ACCESS_RESULT)
    VALUES (P_USER_NAME, P_RESOURCE_NAME, P_ACCESS_LEVEL, 
            CASE WHEN has_access THEN 'GRANTED' ELSE 'DENIED' END);
    
    RETURN has_access;
END;
$$;

-- Grant access procedure
CREATE OR REPLACE PROCEDURE SP_GRANT_ACCESS(
    P_USER_NAME STRING,
    P_RESOURCE_TYPE STRING,
    P_RESOURCE_NAME STRING,
    P_ACCESS_LEVEL STRING,
    P_EXPIRES_AT TIMESTAMP_NTZ DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO USER_ACCESS_CONTROL 
    (USER_NAME, RESOURCE_TYPE, RESOURCE_NAME, ACCESS_LEVEL, EXPIRES_AT)
    VALUES (P_USER_NAME, P_RESOURCE_TYPE, P_RESOURCE_NAME, P_ACCESS_LEVEL, P_EXPIRES_AT);
    
    RETURN 'Access granted to ' || P_USER_NAME || ' for ' || P_RESOURCE_NAME || ' (' || P_ACCESS_LEVEL || ')';
END;
$$;

-- Secure procedure wrapper for sp_example
CREATE OR REPLACE PROCEDURE SP_SECURE_EXAMPLE(P_CALLING_USER STRING DEFAULT NULL)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    current_user_name STRING;
    access_granted BOOLEAN;
    result STRING;
BEGIN
    -- Get current user if not provided
    SET current_user_name = COALESCE(P_CALLING_USER, CURRENT_USER());
    
    -- Check access
    CALL SP_CHECK_ACCESS(current_user_name, 'sp_example', 'EXECUTE') INTO access_granted;
    
    IF (access_granted) THEN
        -- Call the actual procedure (assuming it exists)
        SET result = 'Access granted! Hello from secure sp_example! User: ' || current_user_name || 
                     ' Time: ' || CURRENT_TIMESTAMP()::STRING;
    ELSE
        SET result = 'Access denied for user: ' || current_user_name;
    END IF;
    
    RETURN result;
END;
$$;

-- ============================================================================
-- Setup Default Access
-- ============================================================================

-- Grant access to sf_api_user for sp_example
CALL SP_GRANT_ACCESS('sf_api_user', 'PROCEDURE', 'sp_example', 'EXECUTE', NULL);

-- Grant access with expiration (30 days)
CALL SP_GRANT_ACCESS('sf_api_user', 'PROCEDURE', 'sp_example_with_params', 'EXECUTE', 
                     DATEADD(DAY, 30, CURRENT_DATE()));

-- Create role for UBAC access
CREATE ROLE IF NOT EXISTS UBAC_USER_ROLE;

-- Grant permissions to the role
GRANT USAGE ON DATABASE UBAC_DB TO ROLE UBAC_USER_ROLE;
GRANT USAGE ON SCHEMA UBAC_DB.ACCESS_CONTROL TO ROLE UBAC_USER_ROLE;
GRANT SELECT ON USER_ACCESS_CONTROL TO ROLE UBAC_USER_ROLE;
GRANT SELECT ON SIMPLE_ACCESS_LOG TO ROLE UBAC_USER_ROLE;
GRANT USAGE ON PROCEDURE SP_CHECK_ACCESS(STRING, STRING, STRING) TO ROLE UBAC_USER_ROLE;
GRANT USAGE ON PROCEDURE SP_SECURE_EXAMPLE(STRING) TO ROLE UBAC_USER_ROLE;

-- Grant role to sf_api_user
GRANT ROLE UBAC_USER_ROLE TO USER sf_api_user;

-- Test the setup
SELECT 'Simple UBAC setup completed!' AS status;

-- Show granted access
SELECT * FROM USER_ACCESS_CONTROL WHERE USER_NAME = 'sf_api_user';

-- Test the secure procedure
CALL SP_SECURE_EXAMPLE('sf_api_user');
