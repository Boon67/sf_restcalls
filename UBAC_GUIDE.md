# User-Based Access Control (UBAC) Guide

This guide explains how to implement and use User-Based Access Control (UBAC) in Snowflake using the provided stored procedures.

## 📋 Overview

User-Based Access Control (UBAC) provides fine-grained access control based on user identity and attributes, going beyond traditional role-based access control (RBAC) to enable:

- **Dynamic Access Control** - Decisions based on user attributes
- **Resource-Level Permissions** - Control access to specific procedures, tables, etc.
- **Row-Level Security** - Filter data based on user context
- **Comprehensive Auditing** - Track all access decisions
- **Time-Based Access** - Temporary permissions with expiration

## 🚀 Quick Start

### Option 1: Simple UBAC (Recommended for Testing)

```sql
-- Execute as ACCOUNTADMIN
@simple_ubac_setup.sql
```

### Option 2: Full UBAC Implementation

```sql
-- Execute as ACCOUNTADMIN  
@create_ubac_procedures.sql
```

## 🛠 Simple UBAC Implementation

### Core Components

1. **`USER_ACCESS_CONTROL`** - Stores user permissions
2. **`SIMPLE_ACCESS_LOG`** - Audit trail
3. **`SP_CHECK_ACCESS()`** - Validates user access
4. **`SP_GRANT_ACCESS()`** - Grants permissions
5. **`SP_SECURE_EXAMPLE()`** - Secure wrapper procedure

### Usage Examples

#### Grant Access to User
```sql
-- Grant execute permission to user for sp_example
CALL SP_GRANT_ACCESS(
    'sf_api_user',           -- User name
    'PROCEDURE',             -- Resource type  
    'sp_example',            -- Resource name
    'EXECUTE',               -- Access level
    NULL                     -- No expiration
);

-- Grant temporary access (30 days)
CALL SP_GRANT_ACCESS(
    'john_doe',
    'TABLE', 
    'SENSITIVE_DATA',
    'READ',
    DATEADD(DAY, 30, CURRENT_DATE())
);
```

#### Check User Access
```sql
-- Check if user has execute permission
CALL SP_CHECK_ACCESS('sf_api_user', 'sp_example', 'EXECUTE');
-- Returns: TRUE or FALSE
```

#### Use Secure Procedure
```sql
-- Call secure wrapper (checks access automatically)
CALL SP_SECURE_EXAMPLE('sf_api_user');
-- Returns: Access granted message or denial
```

#### View User Permissions
```sql
-- View all permissions for a user
SELECT * FROM USER_ACCESS_CONTROL 
WHERE USER_NAME = 'sf_api_user' 
  AND IS_ACTIVE = TRUE;
```

#### View Access Audit Log
```sql
-- View recent access attempts
SELECT * FROM SIMPLE_ACCESS_LOG 
ORDER BY TIMESTAMP DESC 
LIMIT 10;
```

## 🏗 Full UBAC Implementation

### Advanced Components

1. **User Attributes** - Store user metadata (department, clearance level)
2. **Resource Permissions** - Granular resource-level control
3. **Row-Level Security** - Dynamic query filtering
4. **Comprehensive Auditing** - Detailed access logging
5. **Condition-Based Access** - SQL expressions for complex rules

### Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_CHECK_USER_ACCESS()` | Core access validation |
| `SP_VALIDATE_USER_ATTRIBUTES()` | Attribute-based validation |
| `SP_GRANT_RESOURCE_ACCESS()` | Grant resource permissions |
| `SP_SET_USER_ATTRIBUTE()` | Manage user attributes |
| `SP_GET_USER_PERMISSIONS()` | View user permissions |
| `SP_GET_ACCESS_AUDIT_REPORT()` | Generate audit reports |
| `SP_APPLY_ROW_LEVEL_SECURITY()` | Apply row filtering |

### Advanced Usage Examples

#### Set User Attributes
```sql
-- Set user department
CALL SP_SET_USER_ATTRIBUTE(
    'sf_api_user',
    'DEPARTMENT', 
    'ANALYTICS',
    NULL  -- No expiration
);

-- Set clearance level with expiration
CALL SP_SET_USER_ATTRIBUTE(
    'contractor_user',
    'CLEARANCE_LEVEL',
    'STANDARD',
    DATEADD(MONTH, 6, CURRENT_DATE())
);
```

#### Grant Conditional Access
```sql
-- Grant table access with row-level condition
CALL SP_GRANT_RESOURCE_ACCESS(
    'TABLE',                                    -- Resource type
    'EMPLOYEE_DATA',                           -- Resource name
    'SELECT',                                  -- Permission type
    'hr_manager',                              -- User name
    NULL,                                      -- Role name (NULL for user)
    DATEADD(YEAR, 1, CURRENT_DATE()),        -- Expiration
    'DEPARTMENT = ''HUMAN_RESOURCES'''         -- Row-level condition
);
```

#### Check Access with Full Validation
```sql
-- Comprehensive access check (includes attributes)
CALL SP_CHECK_USER_ACCESS(
    'sf_api_user',
    'PROCEDURE',
    'sp_sensitive_data',
    'EXECUTE'
);
```

#### Generate Access Report
```sql
-- Audit report for last 7 days
CALL SP_GET_ACCESS_AUDIT_REPORT(
    DATEADD(DAY, -7, CURRENT_DATE()),
    CURRENT_DATE(),
    'sf_api_user'  -- Specific user (NULL for all users)
);
```

#### View User Permissions Summary
```sql
-- Get comprehensive permissions for user
CALL SP_GET_USER_PERMISSIONS('sf_api_user');
```

## 🔒 Security Features

### Access Control Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| `READ` | View/Select data | Data consumers |
| `WRITE` | Insert/Update/Delete | Data producers |
| `EXECUTE` | Run procedures/functions | API users |
| `ADMIN` | Full administrative access | System administrators |

### User Attributes

| Attribute | Description | Example Values |
|-----------|-------------|----------------|
| `DEPARTMENT` | User's department | ANALYTICS, HR, FINANCE |
| `CLEARANCE_LEVEL` | Security clearance | STANDARD, HIGH, ADMIN |
| `REGION` | Geographic region | US_WEST, EU, ASIA |
| `EMPLOYMENT_TYPE` | Employment status | EMPLOYEE, CONTRACTOR |

### Conditional Access

Row-level security expressions:
```sql
-- Department-based filtering
'DEPARTMENT = ''ANALYTICS'''

-- Date-based filtering  
'CREATED_DATE >= DATEADD(DAY, -30, CURRENT_DATE())'

-- Multi-condition filtering
'DEPARTMENT IN (''FINANCE'', ''ANALYTICS'') AND REGION = ''US_WEST'''
```

## 🧪 Testing Your UBAC Setup

### 1. Basic Access Test
```sql
-- Test user access
CALL SP_CHECK_ACCESS('sf_api_user', 'sp_example', 'EXECUTE');

-- Should return TRUE if access granted
```

### 2. Secure Procedure Test
```sql
-- Test secure wrapper
CALL SP_SECURE_EXAMPLE('sf_api_user');

-- Should return success message or access denied
```

### 3. Audit Log Verification
```sql
-- Check audit trail
SELECT 
    USER_NAME,
    RESOURCE_NAME,
    ACTION,
    ACCESS_RESULT,
    TIMESTAMP
FROM SIMPLE_ACCESS_LOG 
ORDER BY TIMESTAMP DESC 
LIMIT 5;
```

### 4. Permissions Verification
```sql
-- Verify granted permissions
SELECT 
    USER_NAME,
    RESOURCE_TYPE,
    RESOURCE_NAME,
    ACCESS_LEVEL,
    GRANTED_AT,
    EXPIRES_AT
FROM USER_ACCESS_CONTROL
WHERE USER_NAME = 'sf_api_user';
```

## 🔧 Integration with sf_restcalls Library

### Python Integration
```python
from sf_restcalls import SnowflakeClient

# Use secure procedure that checks UBAC
with SnowflakeClient(...) as client:
    # This will go through UBAC validation
    result = client.call_stored_procedure("SP_SECURE_EXAMPLE", ["sf_api_user"])
    print(result)
```

### curl Integration
```bash
# Call secure procedure via API
./snowflake_curl_script.sh SP_SECURE_EXAMPLE "sf_api_user"
```

### Creating UBAC-Protected Procedures

```sql
-- Template for UBAC-protected procedure
CREATE OR REPLACE PROCEDURE SP_PROTECTED_PROCEDURE(P_USER STRING, P_PARAM STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    access_granted BOOLEAN;
    result STRING;
BEGIN
    -- Check UBAC access
    CALL SP_CHECK_ACCESS(P_USER, 'my_protected_resource', 'EXECUTE') INTO access_granted;
    
    IF (access_granted) THEN
        -- Your business logic here
        SET result = 'Operation completed for: ' || P_PARAM;
    ELSE
        SET result = 'Access denied for user: ' || P_USER;
    END IF;
    
    RETURN result;
END;
$$;
```

## 📊 Monitoring and Maintenance

### Regular Maintenance Tasks

1. **Review Expired Permissions**
```sql
-- Find expired permissions
SELECT * FROM USER_ACCESS_CONTROL 
WHERE EXPIRES_AT < CURRENT_TIMESTAMP() AND IS_ACTIVE = TRUE;

-- Deactivate expired permissions
UPDATE USER_ACCESS_CONTROL 
SET IS_ACTIVE = FALSE 
WHERE EXPIRES_AT < CURRENT_TIMESTAMP();
```

2. **Monitor Access Patterns**
```sql
-- Most accessed resources
SELECT 
    RESOURCE_NAME,
    COUNT(*) AS ACCESS_COUNT,
    COUNT(CASE WHEN ACCESS_RESULT = 'DENIED' THEN 1 END) AS DENIED_COUNT
FROM SIMPLE_ACCESS_LOG 
WHERE TIMESTAMP >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY RESOURCE_NAME
ORDER BY ACCESS_COUNT DESC;
```

3. **User Access Summary**
```sql
-- Users with most access attempts
SELECT 
    USER_NAME,
    COUNT(*) AS TOTAL_ATTEMPTS,
    COUNT(CASE WHEN ACCESS_RESULT = 'GRANTED' THEN 1 END) AS GRANTED,
    COUNT(CASE WHEN ACCESS_RESULT = 'DENIED' THEN 1 END) AS DENIED
FROM SIMPLE_ACCESS_LOG
WHERE TIMESTAMP >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY USER_NAME
ORDER BY TOTAL_ATTEMPTS DESC;
```

## 🚨 Troubleshooting

### Common Issues

1. **Access Denied Unexpectedly**
   - Check if permission exists: `SELECT * FROM USER_ACCESS_CONTROL WHERE USER_NAME = 'username'`
   - Verify permission hasn't expired
   - Check if permission is active

2. **Procedure Not Found**
   - Ensure UBAC procedures are created in the correct schema
   - Verify user has USAGE permission on procedures

3. **Audit Log Empty**
   - Check if `SP_CHECK_ACCESS` is being called
   - Verify INSERT permissions on audit table

### Debug Queries

```sql
-- Check current user context
SELECT 
    CURRENT_USER() AS user,
    CURRENT_ROLE() AS role,
    CURRENT_DATABASE() AS database,
    CURRENT_SCHEMA() AS schema;

-- List available UBAC procedures
SHOW PROCEDURES IN SCHEMA UBAC_DB.ACCESS_CONTROL;

-- Check role grants
SHOW GRANTS TO ROLE UBAC_USER_ROLE;
```

## 🔄 Migration and Cleanup

### Remove UBAC System
```sql
-- Warning: This removes all UBAC data and procedures

-- Drop procedures
DROP PROCEDURE IF EXISTS SP_CHECK_ACCESS(STRING, STRING, STRING);
DROP PROCEDURE IF EXISTS SP_GRANT_ACCESS(STRING, STRING, STRING, STRING, TIMESTAMP_NTZ);
DROP PROCEDURE IF EXISTS SP_SECURE_EXAMPLE(STRING);

-- Drop tables
DROP TABLE IF EXISTS USER_ACCESS_CONTROL;
DROP TABLE IF EXISTS SIMPLE_ACCESS_LOG;

-- Drop role
DROP ROLE IF EXISTS UBAC_USER_ROLE;

-- Drop schema and database
DROP SCHEMA IF EXISTS UBAC_DB.ACCESS_CONTROL;
DROP DATABASE IF EXISTS UBAC_DB;
```

## 📚 Best Practices

1. **Principle of Least Privilege** - Grant minimum necessary access
2. **Regular Access Reviews** - Periodically audit and cleanup permissions
3. **Time-Limited Access** - Use expiration dates for temporary access
4. **Comprehensive Logging** - Monitor all access attempts
5. **Attribute Management** - Keep user attributes current and accurate
6. **Testing** - Validate UBAC rules before deploying to production
7. **Documentation** - Document access control policies and procedures

## 🆘 Support

For UBAC implementation issues:
1. Review the troubleshooting section
2. Check Snowflake error logs and query history
3. Validate user permissions and role assignments
4. Ensure all prerequisites are met
5. Test with simple cases before complex scenarios
