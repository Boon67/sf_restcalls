# Snowflake User Setup Guide

This guide walks through setting up a Snowflake user account with PAT token authentication for use with the sf_restcalls library.

## 📋 Prerequisites

- Snowflake account with ACCOUNTADMIN or equivalent privileges
- Access to Snowflake web UI or SQL client
- Target database, schema, and warehouse (or permissions to create them)

## 🚀 Quick Setup (Recommended)

### Step 1: Run the Quick Setup Script

Execute the `quick_user_setup.sql` script as an account administrator:

```sql
-- Execute this file in Snowflake
@quick_user_setup.sql
```

This creates:
- Database: `ANALYTICS_DB`
- Schema: `ANALYTICS_DB.PUBLIC`
- Warehouse: `COMPUTE_WH`
- Role: `API_USER_ROLE`
- User: `sf_api_user`
- Stored Procedure: `sp_example()`

### Step 2: Generate PAT Token

#### Option A: Using Snowflake Web UI

1. Log into Snowflake web interface as `sf_api_user`
2. Go to **User Preferences** → **Personal Access Tokens**
3. Click **Generate Token**
4. Enter token name: `API_Access_Token`
5. Set expiration (recommended: 90 days)
6. Click **Generate**
7. **Copy the token immediately** (it won't be shown again)

#### Option B: Using SQL (as ACCOUNTADMIN)

```sql
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE PERSONAL ACCESS TOKEN sf_api_user_token
    FOR USER sf_api_user
    EXPIRES = DATEADD(DAY, 90, CURRENT_DATE())
    COMMENT = 'PAT token for API access';

-- View token details (token value shown only once)
SHOW PERSONAL ACCESS TOKENS FOR USER sf_api_user;
```

### Step 3: Configure Environment

Set up your environment variables:

```bash
export SNOWFLAKE_ACCOUNT="your-account.snowflakecomputing.com"
export SNOWFLAKE_USERNAME="sf_api_user"
export SNOWFLAKE_TOKEN="your-generated-pat-token"
export SNOWFLAKE_DATABASE="ANALYTICS_DB"
export SNOWFLAKE_SCHEMA="PUBLIC"
export SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
export SNOWFLAKE_ROLE="API_USER_ROLE"
```

### Step 4: Test the Setup

```bash
# Test with Python library
python3 -c "
from sf_restcalls import SnowflakeClient
with SnowflakeClient(
    account='$SNOWFLAKE_ACCOUNT',
    username='$SNOWFLAKE_USERNAME',
    token='$SNOWFLAKE_TOKEN',
    database='$SNOWFLAKE_DATABASE',
    schema='$SNOWFLAKE_SCHEMA',
    warehouse='$SNOWFLAKE_WAREHOUSE'
) as client:
    result = client.call_sp_example()
    print('Success:', result)
"

# Test with curl script
./snowflake_curl_script.sh sp_example
```

## 🔧 Advanced Setup

For more control and additional features, use the comprehensive `setup_user_with_pat.sql` script:

```sql
-- Execute the full setup script
@setup_user_with_pat.sql
```

This provides:
- Multiple roles with specific privileges
- Additional stored procedures with parameters
- Comprehensive security configuration
- Sample data procedures
- Detailed verification queries

## 🎯 What Gets Created

### Resources
| Resource | Name | Purpose |
|----------|------|---------|
| Database | `ANALYTICS_DB` | Container for schemas and objects |
| Schema | `ANALYTICS_DB.PUBLIC` | Default schema for procedures |
| Warehouse | `COMPUTE_WH` | Compute resource for queries |
| Role | `API_USER_ROLE` | Role with necessary privileges |
| User | `sf_api_user` | API user account |

### Stored Procedures
| Procedure | Parameters | Returns | Purpose |
|-----------|------------|---------|---------|
| `sp_example()` | None | String | Basic test procedure |
| `sp_example_with_params()` | text, number, boolean | Table | Parameter handling test |
| `sp_get_sample_data()` | None | Table | Sample data generation |

### User Configuration
- **Default Warehouse**: `COMPUTE_WH`
- **Default Database**: `ANALYTICS_DB`
- **Default Schema**: `PUBLIC`
- **Default Role**: `API_USER_ROLE`
- **Authentication**: PAT token enabled
- **Password Change**: Not required

## 🔒 Security Considerations

### Principle of Least Privilege
- User has access only to specified database/schema
- Role grants minimum necessary privileges
- Warehouse usage is controlled

### Token Management
- Set reasonable expiration dates (90 days recommended)
- Rotate tokens regularly
- Revoke unused tokens immediately
- Store tokens securely (environment variables, secret managers)

### Network Security
- Consider IP allowlists if needed
- Use HTTPS for all API calls
- Monitor API usage through Snowflake query history

## 🧪 Testing Your Setup

### 1. Verify User Creation
```sql
SHOW USERS LIKE 'sf_api_user';
DESC USER sf_api_user;
```

### 2. Verify Privileges
```sql
SHOW GRANTS TO USER sf_api_user;
SHOW GRANTS TO ROLE API_USER_ROLE;
```

### 3. Test Procedures
```sql
USE ROLE API_USER_ROLE;
USE DATABASE ANALYTICS_DB;
USE SCHEMA PUBLIC;
USE WAREHOUSE COMPUTE_WH;

CALL sp_example();
```

### 4. Test API Access
```bash
# Test connection
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SNOWFLAKE_TOKEN" \
    -d '{"statement": "SELECT CURRENT_USER(), CURRENT_ROLE();"}' \
    "https://$SNOWFLAKE_ACCOUNT/api/v2/statements"
```

## 🛠 Troubleshooting

### Common Issues

#### Authentication Errors
```
Error: Authentication failed
```
**Solution**: Verify PAT token is correct and not expired

#### Permission Denied
```
Error: Insufficient privileges to operate on procedure
```
**Solution**: Check role grants and ensure user has necessary privileges

#### Procedure Not Found
```
Error: Object 'SP_EXAMPLE' does not exist
```
**Solution**: Verify procedure exists and user has access:
```sql
SHOW PROCEDURES IN SCHEMA ANALYTICS_DB.PUBLIC;
```

#### Connection Issues
```
Error: Failed to connect to Snowflake
```
**Solution**: Verify account URL format and network connectivity

### Debug Commands

```sql
-- Check current context
SELECT 
    CURRENT_USER() AS user,
    CURRENT_ROLE() AS role,
    CURRENT_DATABASE() AS database,
    CURRENT_SCHEMA() AS schema,
    CURRENT_WAREHOUSE() AS warehouse;

-- List available procedures
SHOW PROCEDURES IN SCHEMA ANALYTICS_DB.PUBLIC;

-- Check role privileges
SHOW GRANTS TO ROLE API_USER_ROLE;
```

## 🔄 Cleanup (Optional)

To remove the created resources:

```sql
-- Drop user and roles
DROP USER IF EXISTS sf_api_user;
DROP ROLE IF EXISTS API_USER_ROLE;

-- Drop procedures
USE DATABASE ANALYTICS_DB;
USE SCHEMA PUBLIC;
DROP PROCEDURE IF EXISTS sp_example();

-- Drop warehouse, schema, database (if desired)
DROP WAREHOUSE IF EXISTS COMPUTE_WH;
DROP SCHEMA IF EXISTS ANALYTICS_DB.PUBLIC;
DROP DATABASE IF EXISTS ANALYTICS_DB;
```

## 📚 Next Steps

1. **Customize Procedures**: Modify or create additional stored procedures for your use case
2. **Add Security**: Implement additional security measures as needed
3. **Monitor Usage**: Set up monitoring for API calls and resource usage
4. **Scale Resources**: Adjust warehouse size based on workload requirements
5. **Automate**: Consider automation for user provisioning and token rotation

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Verify all prerequisites are met
3. Review Snowflake documentation for your specific account configuration
4. Contact your Snowflake administrator for account-specific issues
