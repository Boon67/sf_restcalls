-- ============================================================================
-- User-Based Access Control (UBAC) Stored Procedures
-- ============================================================================
-- This script creates stored procedures that implement User-Based Access Control
-- allowing fine-grained access control based on user identity, roles, and attributes.
--
-- UBAC Features:
-- 1. User identity verification
-- 2. Dynamic access control based on user attributes
-- 3. Resource-level permissions
-- 4. Audit logging for access control decisions
-- 5. Row-level security enforcement
--
-- Prerequisites:
-- 1. Execute as ACCOUNTADMIN or user with SECURITYADMIN privileges
-- 2. Target database and schema must exist
-- 3. Users and roles must be properly configured
-- ============================================================================

-- Set execution context
USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- SECTION 1: Create UBAC Infrastructure
-- ============================================================================

-- Create UBAC database and schema if they don't exist
CREATE DATABASE IF NOT EXISTS UBAC_DB
    COMMENT = 'Database for User-Based Access Control implementation';

CREATE SCHEMA IF NOT EXISTS UBAC_DB.SECURITY
    COMMENT = 'Schema containing UBAC security procedures and tables';

USE DATABASE UBAC_DB;
USE SCHEMA SECURITY;

-- Create warehouse for UBAC operations
CREATE WAREHOUSE IF NOT EXISTS UBAC_WH
    WITH 
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for UBAC operations';

-- ============================================================================
-- SECTION 2: Create UBAC Control Tables
-- ============================================================================

-- User attributes table for UBAC decisions
CREATE TABLE IF NOT EXISTS USER_ATTRIBUTES (
    USER_NAME STRING NOT NULL,
    ATTRIBUTE_NAME STRING NOT NULL,
    ATTRIBUTE_VALUE STRING,
    EFFECTIVE_DATE TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    EXPIRY_DATE TIMESTAMP_NTZ,
    CREATED_BY STRING DEFAULT CURRENT_USER(),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    MODIFIED_BY STRING DEFAULT CURRENT_USER(),
    MODIFIED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (USER_NAME, ATTRIBUTE_NAME)
) COMMENT = 'User attributes for UBAC access control decisions';

-- Resource permissions table
CREATE TABLE IF NOT EXISTS RESOURCE_PERMISSIONS (
    RESOURCE_ID STRING NOT NULL,
    RESOURCE_TYPE STRING NOT NULL, -- TABLE, PROCEDURE, DATABASE, SCHEMA, etc.
    RESOURCE_NAME STRING NOT NULL,
    PERMISSION_TYPE STRING NOT NULL, -- SELECT, INSERT, UPDATE, DELETE, EXECUTE, etc.
    USER_NAME STRING,
    ROLE_NAME STRING,
    CONDITION_EXPR STRING, -- Optional SQL condition for row-level security
    GRANTED_BY STRING DEFAULT CURRENT_USER(),
    GRANTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    EXPIRES_AT TIMESTAMP_NTZ,
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (RESOURCE_ID, PERMISSION_TYPE, COALESCE(USER_NAME, ROLE_NAME))
) COMMENT = 'Resource-level permissions for UBAC';

-- Access audit log
CREATE TABLE IF NOT EXISTS ACCESS_AUDIT_LOG (
    AUDIT_ID STRING DEFAULT RANDOM()::STRING,
    USER_NAME STRING NOT NULL,
    RESOURCE_TYPE STRING NOT NULL,
    RESOURCE_NAME STRING NOT NULL,
    ACTION_TYPE STRING NOT NULL,
    ACCESS_GRANTED BOOLEAN NOT NULL,
    DENIAL_REASON STRING,
    SESSION_ID STRING DEFAULT CURRENT_SESSION(),
    CLIENT_IP STRING,
    USER_AGENT STRING,
    TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    QUERY_ID STRING DEFAULT CURRENT_QUERY_ID()
) COMMENT = 'Audit log for UBAC access decisions';

-- ============================================================================
-- SECTION 3: UBAC Core Stored Procedures
-- ============================================================================

-- Procedure to check if user has access to a resource
CREATE OR REPLACE PROCEDURE SP_CHECK_USER_ACCESS(
    P_USER_NAME STRING,
    P_RESOURCE_TYPE STRING,
    P_RESOURCE_NAME STRING,
    P_ACTION_TYPE STRING
)
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
DECLARE
    access_granted BOOLEAN DEFAULT FALSE;
    denial_reason STRING DEFAULT 'Access denied by UBAC policy';
    user_roles ARRAY;
    resource_count INTEGER;
    attribute_check BOOLEAN DEFAULT TRUE;
BEGIN
    -- Validate input parameters
    IF (P_USER_NAME IS NULL OR P_RESOURCE_TYPE IS NULL OR 
        P_RESOURCE_NAME IS NULL OR P_ACTION_TYPE IS NULL) THEN
        CALL SP_LOG_ACCESS_AUDIT(P_USER_NAME, P_RESOURCE_TYPE, P_RESOURCE_NAME, 
                                 P_ACTION_TYPE, FALSE, 'Invalid parameters');
        RETURN FALSE;
    END IF;
    
    -- Get user's current roles
    SELECT ARRAY_AGG(ROLE_NAME) INTO user_roles
    FROM TABLE(INFORMATION_SCHEMA.APPLICABLE_ROLES())
    WHERE GRANTEE_NAME = P_USER_NAME;
    
    -- Check direct user permissions
    SELECT COUNT(*) INTO resource_count
    FROM RESOURCE_PERMISSIONS
    WHERE RESOURCE_TYPE = P_RESOURCE_TYPE
      AND RESOURCE_NAME = P_RESOURCE_NAME
      AND PERMISSION_TYPE = P_ACTION_TYPE
      AND USER_NAME = P_USER_NAME
      AND IS_ACTIVE = TRUE
      AND (EXPIRES_AT IS NULL OR EXPIRES_AT > CURRENT_TIMESTAMP());
    
    IF (resource_count > 0) THEN
        SET access_granted = TRUE;
    ELSE
        -- Check role-based permissions
        SELECT COUNT(*) INTO resource_count
        FROM RESOURCE_PERMISSIONS rp
        WHERE rp.RESOURCE_TYPE = P_RESOURCE_TYPE
          AND rp.RESOURCE_NAME = P_RESOURCE_NAME
          AND rp.PERMISSION_TYPE = P_ACTION_TYPE
          AND rp.ROLE_NAME IN (SELECT VALUE FROM TABLE(FLATTEN(user_roles)))
          AND rp.IS_ACTIVE = TRUE
          AND (rp.EXPIRES_AT IS NULL OR rp.EXPIRES_AT > CURRENT_TIMESTAMP());
        
        IF (resource_count > 0) THEN
            SET access_granted = TRUE;
        END IF;
    END IF;
    
    -- Additional attribute-based checks
    IF (access_granted = TRUE) THEN
        -- Check if user has required attributes (example: department, clearance_level)
        CALL SP_VALIDATE_USER_ATTRIBUTES(P_USER_NAME, P_RESOURCE_TYPE, P_RESOURCE_NAME) 
            INTO attribute_check;
        
        IF (attribute_check = FALSE) THEN
            SET access_granted = FALSE;
            SET denial_reason = 'User attributes do not meet resource requirements';
        END IF;
    END IF;
    
    -- Log the access decision
    CALL SP_LOG_ACCESS_AUDIT(P_USER_NAME, P_RESOURCE_TYPE, P_RESOURCE_NAME, 
                             P_ACTION_TYPE, access_granted, 
                             CASE WHEN access_granted THEN NULL ELSE denial_reason END);
    
    RETURN access_granted;
END;
$$
COMMENT = 'Core UBAC procedure to check user access to resources';

-- Procedure to validate user attributes for resource access
CREATE OR REPLACE PROCEDURE SP_VALIDATE_USER_ATTRIBUTES(
    P_USER_NAME STRING,
    P_RESOURCE_TYPE STRING,
    P_RESOURCE_NAME STRING
)
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
DECLARE
    attribute_valid BOOLEAN DEFAULT TRUE;
    user_department STRING;
    user_clearance_level STRING;
    required_clearance STRING;
BEGIN
    -- Get user attributes
    SELECT ATTRIBUTE_VALUE INTO user_department
    FROM USER_ATTRIBUTES
    WHERE USER_NAME = P_USER_NAME 
      AND ATTRIBUTE_NAME = 'DEPARTMENT'
      AND (EXPIRY_DATE IS NULL OR EXPIRY_DATE > CURRENT_TIMESTAMP());
    
    SELECT ATTRIBUTE_VALUE INTO user_clearance_level
    FROM USER_ATTRIBUTES
    WHERE USER_NAME = P_USER_NAME 
      AND ATTRIBUTE_NAME = 'CLEARANCE_LEVEL'
      AND (EXPIRY_DATE IS NULL OR EXPIRY_DATE > CURRENT_TIMESTAMP());
    
    -- Example: Check clearance level for sensitive resources
    IF (P_RESOURCE_TYPE = 'TABLE' AND P_RESOURCE_NAME LIKE '%SENSITIVE%') THEN
        IF (user_clearance_level IS NULL OR user_clearance_level NOT IN ('HIGH', 'ADMIN')) THEN
            SET attribute_valid = FALSE;
        END IF;
    END IF;
    
    -- Example: Department-based access control
    IF (P_RESOURCE_TYPE = 'TABLE' AND P_RESOURCE_NAME LIKE '%HR_%') THEN
        IF (user_department IS NULL OR user_department != 'HUMAN_RESOURCES') THEN
            SET attribute_valid = FALSE;
        END IF;
    END IF;
    
    RETURN attribute_valid;
END;
$$
COMMENT = 'Validates user attributes against resource requirements';

-- Procedure to log access audit events
CREATE OR REPLACE PROCEDURE SP_LOG_ACCESS_AUDIT(
    P_USER_NAME STRING,
    P_RESOURCE_TYPE STRING,
    P_RESOURCE_NAME STRING,
    P_ACTION_TYPE STRING,
    P_ACCESS_GRANTED BOOLEAN,
    P_DENIAL_REASON STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO ACCESS_AUDIT_LOG (
        USER_NAME,
        RESOURCE_TYPE,
        RESOURCE_NAME,
        ACTION_TYPE,
        ACCESS_GRANTED,
        DENIAL_REASON,
        CLIENT_IP,
        USER_AGENT
    ) VALUES (
        P_USER_NAME,
        P_RESOURCE_TYPE,
        P_RESOURCE_NAME,
        P_ACTION_TYPE,
        P_ACCESS_GRANTED,
        P_DENIAL_REASON,
        CURRENT_CLIENT_IP(),
        'Snowflake-UBAC-System'
    );
    
    RETURN 'Audit log entry created for user: ' || P_USER_NAME;
END;
$$
COMMENT = 'Logs UBAC access decisions for audit purposes';

-- ============================================================================
-- SECTION 4: UBAC Management Procedures
-- ============================================================================

-- Procedure to grant resource access to user
CREATE OR REPLACE PROCEDURE SP_GRANT_RESOURCE_ACCESS(
    P_RESOURCE_TYPE STRING,
    P_RESOURCE_NAME STRING,
    P_PERMISSION_TYPE STRING,
    P_USER_NAME STRING,
    P_ROLE_NAME STRING,
    P_EXPIRES_AT TIMESTAMP_NTZ,
    P_CONDITION_EXPR STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    resource_id STRING;
BEGIN
    -- Validate that either user or role is specified, not both
    IF ((P_USER_NAME IS NULL AND P_ROLE_NAME IS NULL) OR 
        (P_USER_NAME IS NOT NULL AND P_ROLE_NAME IS NOT NULL)) THEN
        RETURN 'Error: Specify either USER_NAME or ROLE_NAME, not both or neither';
    END IF;
    
    -- Generate resource ID
    SET resource_id = P_RESOURCE_TYPE || '_' || P_RESOURCE_NAME || '_' || RANDOM()::STRING;
    
    -- Insert permission record
    INSERT INTO RESOURCE_PERMISSIONS (
        RESOURCE_ID,
        RESOURCE_TYPE,
        RESOURCE_NAME,
        PERMISSION_TYPE,
        USER_NAME,
        ROLE_NAME,
        CONDITION_EXPR,
        EXPIRES_AT
    ) VALUES (
        resource_id,
        P_RESOURCE_TYPE,
        P_RESOURCE_NAME,
        P_PERMISSION_TYPE,
        P_USER_NAME,
        P_ROLE_NAME,
        P_CONDITION_EXPR,
        P_EXPIRES_AT
    );
    
    RETURN 'Access granted. Resource ID: ' || resource_id;
END;
$$
COMMENT = 'Grants resource access to a user or role';

-- Procedure to set user attributes
CREATE OR REPLACE PROCEDURE SP_SET_USER_ATTRIBUTE(
    P_USER_NAME STRING,
    P_ATTRIBUTE_NAME STRING,
    P_ATTRIBUTE_VALUE STRING,
    P_EXPIRY_DATE TIMESTAMP_NTZ
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- Merge user attribute (insert or update)
    MERGE INTO USER_ATTRIBUTES AS target
    USING (SELECT 
               P_USER_NAME AS USER_NAME,
               P_ATTRIBUTE_NAME AS ATTRIBUTE_NAME,
               P_ATTRIBUTE_VALUE AS ATTRIBUTE_VALUE,
               P_EXPIRY_DATE AS EXPIRY_DATE,
               CURRENT_USER() AS MODIFIED_BY,
               CURRENT_TIMESTAMP() AS MODIFIED_AT
          ) AS source
    ON target.USER_NAME = source.USER_NAME 
       AND target.ATTRIBUTE_NAME = source.ATTRIBUTE_NAME
    WHEN MATCHED THEN
        UPDATE SET 
            ATTRIBUTE_VALUE = source.ATTRIBUTE_VALUE,
            EXPIRY_DATE = source.EXPIRY_DATE,
            MODIFIED_BY = source.MODIFIED_BY,
            MODIFIED_AT = source.MODIFIED_AT
    WHEN NOT MATCHED THEN
        INSERT (USER_NAME, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, EXPIRY_DATE, 
                CREATED_BY, MODIFIED_BY)
        VALUES (source.USER_NAME, source.ATTRIBUTE_NAME, source.ATTRIBUTE_VALUE,
                source.EXPIRY_DATE, source.MODIFIED_BY, source.MODIFIED_BY);
    
    RETURN 'User attribute set for: ' || P_USER_NAME || '.' || P_ATTRIBUTE_NAME;
END;
$$
COMMENT = 'Sets or updates user attributes for UBAC';

-- ============================================================================
-- SECTION 5: UBAC Query and Reporting Procedures
-- ============================================================================

-- Procedure to get user permissions summary
CREATE OR REPLACE PROCEDURE SP_GET_USER_PERMISSIONS(P_USER_NAME STRING)
RETURNS TABLE (
    RESOURCE_TYPE STRING,
    RESOURCE_NAME STRING,
    PERMISSION_TYPE STRING,
    GRANTED_VIA STRING,
    EXPIRES_AT TIMESTAMP_NTZ,
    CONDITION_EXPR STRING
)
LANGUAGE SQL
AS
$$
DECLARE
    result_set RESULTSET;
BEGIN
    result_set := (
        SELECT 
            rp.RESOURCE_TYPE,
            rp.RESOURCE_NAME,
            rp.PERMISSION_TYPE,
            CASE 
                WHEN rp.USER_NAME IS NOT NULL THEN 'Direct User Grant'
                ELSE 'Role: ' || rp.ROLE_NAME
            END AS GRANTED_VIA,
            rp.EXPIRES_AT,
            rp.CONDITION_EXPR
        FROM RESOURCE_PERMISSIONS rp
        LEFT JOIN TABLE(INFORMATION_SCHEMA.APPLICABLE_ROLES()) ar 
            ON rp.ROLE_NAME = ar.ROLE_NAME AND ar.GRANTEE_NAME = P_USER_NAME
        WHERE (rp.USER_NAME = P_USER_NAME OR ar.ROLE_NAME IS NOT NULL)
          AND rp.IS_ACTIVE = TRUE
          AND (rp.EXPIRES_AT IS NULL OR rp.EXPIRES_AT > CURRENT_TIMESTAMP())
        ORDER BY rp.RESOURCE_TYPE, rp.RESOURCE_NAME, rp.PERMISSION_TYPE
    );
    
    RETURN TABLE(result_set);
END;
$$
COMMENT = 'Returns comprehensive permissions summary for a user';

-- Procedure to generate access audit report
CREATE OR REPLACE PROCEDURE SP_GET_ACCESS_AUDIT_REPORT(
    P_START_DATE TIMESTAMP_NTZ,
    P_END_DATE TIMESTAMP_NTZ,
    P_USER_NAME STRING DEFAULT NULL
)
RETURNS TABLE (
    USER_NAME STRING,
    RESOURCE_TYPE STRING,
    RESOURCE_NAME STRING,
    ACTION_TYPE STRING,
    ACCESS_GRANTED BOOLEAN,
    DENIAL_REASON STRING,
    ACCESS_COUNT INTEGER,
    LAST_ACCESS TIMESTAMP_NTZ
)
LANGUAGE SQL
AS
$$
DECLARE
    result_set RESULTSET;
BEGIN
    result_set := (
        SELECT 
            USER_NAME,
            RESOURCE_TYPE,
            RESOURCE_NAME,
            ACTION_TYPE,
            ACCESS_GRANTED,
            DENIAL_REASON,
            COUNT(*) AS ACCESS_COUNT,
            MAX(TIMESTAMP) AS LAST_ACCESS
        FROM ACCESS_AUDIT_LOG
        WHERE TIMESTAMP BETWEEN P_START_DATE AND P_END_DATE
          AND (P_USER_NAME IS NULL OR USER_NAME = P_USER_NAME)
        GROUP BY USER_NAME, RESOURCE_TYPE, RESOURCE_NAME, ACTION_TYPE, 
                 ACCESS_GRANTED, DENIAL_REASON
        ORDER BY LAST_ACCESS DESC
    );
    
    RETURN TABLE(result_set);
END;
$$
COMMENT = 'Generates access audit report for specified date range';

-- ============================================================================
-- SECTION 6: UBAC Row-Level Security Implementation
-- ============================================================================

-- Procedure to apply row-level security filter
CREATE OR REPLACE PROCEDURE SP_APPLY_ROW_LEVEL_SECURITY(
    P_USER_NAME STRING,
    P_TABLE_NAME STRING,
    P_BASE_QUERY STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    filtered_query STRING;
    user_department STRING;
    security_condition STRING DEFAULT '';
BEGIN
    -- Get user's department
    SELECT ATTRIBUTE_VALUE INTO user_department
    FROM USER_ATTRIBUTES
    WHERE USER_NAME = P_USER_NAME 
      AND ATTRIBUTE_NAME = 'DEPARTMENT';
    
    -- Apply department-based filtering
    IF (user_department IS NOT NULL) THEN
        SET security_condition = ' AND (DEPARTMENT IS NULL OR DEPARTMENT = ''' || user_department || ''')';
    END IF;
    
    -- Check for additional conditions from RESOURCE_PERMISSIONS
    SELECT CONDITION_EXPR INTO security_condition
    FROM RESOURCE_PERMISSIONS
    WHERE RESOURCE_NAME = P_TABLE_NAME
      AND RESOURCE_TYPE = 'TABLE'
      AND USER_NAME = P_USER_NAME
      AND CONDITION_EXPR IS NOT NULL
      AND IS_ACTIVE = TRUE
    LIMIT 1;
    
    -- Construct filtered query
    IF (security_condition != '') THEN
        SET filtered_query = 'SELECT * FROM (' || P_BASE_QUERY || ') WHERE 1=1' || security_condition;
    ELSE
        SET filtered_query = P_BASE_QUERY;
    END IF;
    
    RETURN filtered_query;
END;
$$
COMMENT = 'Applies row-level security filters to user queries';

-- ============================================================================
-- SECTION 7: Sample Data and Configuration
-- ============================================================================

-- Insert sample user attributes
INSERT INTO USER_ATTRIBUTES (USER_NAME, ATTRIBUTE_NAME, ATTRIBUTE_VALUE) VALUES
('sf_api_user', 'DEPARTMENT', 'ANALYTICS'),
('sf_api_user', 'CLEARANCE_LEVEL', 'STANDARD'),
('sf_api_user', 'REGION', 'US_WEST'),
('john_doe', 'DEPARTMENT', 'HUMAN_RESOURCES'),
('john_doe', 'CLEARANCE_LEVEL', 'HIGH'),
('jane_smith', 'DEPARTMENT', 'FINANCE'),
('jane_smith', 'CLEARANCE_LEVEL', 'ADMIN');

-- Grant sample permissions
CALL SP_GRANT_RESOURCE_ACCESS('PROCEDURE', 'sp_example', 'EXECUTE', 'sf_api_user', NULL, NULL, NULL);
CALL SP_GRANT_RESOURCE_ACCESS('PROCEDURE', 'sp_example_with_params', 'EXECUTE', 'sf_api_user', NULL, NULL, NULL);
CALL SP_GRANT_RESOURCE_ACCESS('TABLE', 'ANALYTICS_DATA', 'SELECT', NULL, 'API_USER_ROLE', NULL, 'DEPARTMENT = ''ANALYTICS''');

-- ============================================================================
-- SECTION 8: UBAC Roles and Grants
-- ============================================================================

-- Create UBAC administration role
CREATE ROLE IF NOT EXISTS UBAC_ADMIN_ROLE
    COMMENT = 'Administrative role for UBAC system management';

-- Grant UBAC admin permissions
GRANT USAGE ON DATABASE UBAC_DB TO ROLE UBAC_ADMIN_ROLE;
GRANT ALL PRIVILEGES ON SCHEMA UBAC_DB.SECURITY TO ROLE UBAC_ADMIN_ROLE;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA UBAC_DB.SECURITY TO ROLE UBAC_ADMIN_ROLE;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA UBAC_DB.SECURITY TO ROLE UBAC_ADMIN_ROLE;
GRANT USAGE ON WAREHOUSE UBAC_WH TO ROLE UBAC_ADMIN_ROLE;

-- Grant UBAC usage permissions to API_USER_ROLE
GRANT USAGE ON DATABASE UBAC_DB TO ROLE API_USER_ROLE;
GRANT USAGE ON SCHEMA UBAC_DB.SECURITY TO ROLE API_USER_ROLE;
GRANT SELECT ON ACCESS_AUDIT_LOG TO ROLE API_USER_ROLE;
GRANT USAGE ON PROCEDURE SP_CHECK_USER_ACCESS(STRING, STRING, STRING, STRING) TO ROLE API_USER_ROLE;
GRANT USAGE ON PROCEDURE SP_GET_USER_PERMISSIONS(STRING) TO ROLE API_USER_ROLE;

-- ============================================================================
-- SECTION 9: Testing and Verification
-- ============================================================================

-- Test the UBAC system
SELECT 'UBAC system setup completed!' AS status;

-- Verify procedures exist
SHOW PROCEDURES IN SCHEMA UBAC_DB.SECURITY;

-- Test user access check
CALL SP_CHECK_USER_ACCESS('sf_api_user', 'PROCEDURE', 'sp_example', 'EXECUTE');

-- View user permissions
CALL SP_GET_USER_PERMISSIONS('sf_api_user');

-- View audit log (should show the test access check)
SELECT * FROM ACCESS_AUDIT_LOG ORDER BY TIMESTAMP DESC LIMIT 5;

-- ============================================================================
-- SECTION 10: Usage Examples
-- ============================================================================

/*
-- Example 1: Check if user can execute a procedure
CALL SP_CHECK_USER_ACCESS('sf_api_user', 'PROCEDURE', 'sp_example', 'EXECUTE');

-- Example 2: Grant table access with condition
CALL SP_GRANT_RESOURCE_ACCESS(
    'TABLE', 
    'EMPLOYEE_DATA', 
    'SELECT', 
    'john_doe', 
    NULL, 
    DATEADD(DAY, 30, CURRENT_DATE()), 
    'DEPARTMENT = ''HUMAN_RESOURCES'''
);

-- Example 3: Set user attribute
CALL SP_SET_USER_ATTRIBUTE(
    'new_user', 
    'CLEARANCE_LEVEL', 
    'STANDARD', 
    DATEADD(YEAR, 1, CURRENT_DATE())
);

-- Example 4: Get audit report
CALL SP_GET_ACCESS_AUDIT_REPORT(
    DATEADD(DAY, -7, CURRENT_DATE()), 
    CURRENT_DATE(), 
    'sf_api_user'
);

-- Example 5: Apply row-level security
CALL SP_APPLY_ROW_LEVEL_SECURITY(
    'sf_api_user', 
    'SENSITIVE_TABLE', 
    'SELECT * FROM SENSITIVE_TABLE'
);
*/

SELECT 'UBAC implementation completed successfully!' AS final_status;
