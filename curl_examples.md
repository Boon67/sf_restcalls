# Snowflake curl Examples

This document provides examples of using curl to call Snowflake stored procedures via the Snowflake SQL API.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Authentication Methods](#authentication-methods)
3. [Basic Examples](#basic-examples)
4. [Advanced Examples](#advanced-examples)
5. [Response Handling](#response-handling)
6. [Troubleshooting](#troubleshooting)

## Quick Start

The easiest way to call Snowflake stored procedures with curl is using the provided script:

```bash
# Set environment variables
export SNOWFLAKE_ACCOUNT="your-account.snowflakecomputing.com"
export SNOWFLAKE_USERNAME="your-username"
export SNOWFLAKE_TOKEN="your-pat-token"
export SNOWFLAKE_DATABASE="your-database"
export SNOWFLAKE_SCHEMA="your-schema"
export SNOWFLAKE_WAREHOUSE="your-warehouse"

# Call sp_example
./snowflake_curl_script.sh

# Call specific procedure with parameters
./snowflake_curl_script.sh my_procedure "param1,param2,123"
```

## Authentication Methods

### 1. Personal Access Token (PAT) - Recommended

```bash
# Set PAT token
export SNOWFLAKE_TOKEN="your-pat-token"
export AUTH_METHOD="pat"

# Use the script
./snowflake_curl_script.sh sp_example
```

### 2. Key-Pair Authentication (JWT)

First, generate a key pair:

```bash
# Generate RSA key pair
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

# Add public key to Snowflake user (run in Snowflake worksheet)
# ALTER USER your_username SET RSA_PUBLIC_KEY='<contents-of-rsa_key.pub>';
```

Then use with the script:

```bash
export PRIVATE_KEY_PATH="./rsa_key.p8"
export AUTH_METHOD="keypair"

./snowflake_curl_script.sh sp_example
```

## Basic Examples

### Call sp_example with no parameters

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_PAT_TOKEN" \
  -H "Accept: application/json" \
  -d '{
    "statement": "CALL sp_example();",
    "database": "your_database",
    "schema": "your_schema", 
    "warehouse": "your_warehouse"
  }' \
  "https://your-account.snowflakecomputing.com/api/v2/statements"
```

### Call procedure with parameters

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_PAT_TOKEN" \
  -H "Accept: application/json" \
  -d '{
    "statement": "CALL my_procedure($1, $2, $3);",
    "bindings": {
      "1": {"type": "TEXT", "value": "param1"},
      "2": {"type": "FIXED", "value": "123"},
      "3": {"type": "BOOLEAN", "value": "true"}
    },
    "database": "your_database",
    "schema": "your_schema",
    "warehouse": "your_warehouse"
  }' \
  "https://your-account.snowflakecomputing.com/api/v2/statements"
```

### Get query results

If the procedure returns a large result set, you may need to fetch results separately:

```bash
# First, submit the statement
STATEMENT_HANDLE=$(curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_PAT_TOKEN" \
  -d '{"statement": "CALL sp_example();"}' \
  "https://your-account.snowflakecomputing.com/api/v2/statements" | \
  jq -r '.statementHandle')

# Then fetch results
curl -X GET \
  -H "Authorization: Bearer YOUR_PAT_TOKEN" \
  "https://your-account.snowflakecomputing.com/api/v2/statements/$STATEMENT_HANDLE"
```

## Advanced Examples

### Asynchronous execution

```bash
# Submit statement asynchronously
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_PAT_TOKEN" \
  -d '{
    "statement": "CALL long_running_procedure();",
    "asyncExec": true,
    "database": "your_database",
    "schema": "your_schema",
    "warehouse": "your_warehouse"
  }' \
  "https://your-account.snowflakecomputing.com/api/v2/statements"
```

### With timeout and row limits

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_PAT_TOKEN" \
  -d '{
    "statement": "CALL sp_example();",
    "timeout": 60,
    "resultSetMetaData": {
      "format": "json",
      "numberOfRowsMaximum": 1000
    },
    "database": "your_database",
    "schema": "your_schema",
    "warehouse": "your_warehouse"
  }' \
  "https://your-account.snowflakecomputing.com/api/v2/statements"
```

### Multiple statements

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_PAT_TOKEN" \
  -d '{
    "statement": "USE DATABASE my_db; USE SCHEMA my_schema; CALL sp_example();",
    "database": "your_database",
    "schema": "your_schema",
    "warehouse": "your_warehouse"
  }' \
  "https://your-account.snowflakecomputing.com/api/v2/statements"
```

## Response Handling

### Successful Response Structure

```json
{
  "resultSetMetaData": {
    "numRows": 1,
    "format": "json",
    "rowType": [
      {
        "name": "COLUMN1",
        "type": "TEXT",
        "nullable": true
      }
    ]
  },
  "data": [
    ["result_value"]
  ],
  "code": "090001",
  "statementStatusUrl": "/api/v2/statements/01234567-89ab-cdef-0123-456789abcdef",
  "requestId": "01234567-89ab-cdef-0123-456789abcdef",
  "sqlState": "00000",
  "statementHandle": "01234567-89ab-cdef-0123-456789abcdef",
  "message": "Statement executed successfully.",
  "createdOn": 1234567890123
}
```

### Error Response Structure

```json
{
  "code": "001003", 
  "message": "SQL compilation error: Object 'PROCEDURE_NAME' does not exist.",
  "sqlState": "42S02",
  "statementHandle": "01234567-89ab-cdef-0123-456789abcdef"
}
```

### Extract data with jq

```bash
# Extract just the data rows
curl ... | jq '.data'

# Extract first row, first column
curl ... | jq '.data[0][0]'

# Extract column names
curl ... | jq '.resultSetMetaData.rowType[].name'

# Check for errors
curl ... | jq 'if .code | startswith("0") then .data else .message end'
```

## Troubleshooting

### Common Issues

1. **Authentication Errors (401)**
   ```bash
   # Check token validity
   echo $SNOWFLAKE_TOKEN | wc -c  # Should be substantial length
   
   # For JWT, check expiration
   echo $JWT_TOKEN | cut -d. -f2 | base64 -d | jq .exp
   ```

2. **Object Not Found (42S02)**
   ```bash
   # Check if procedure exists
   curl -X POST \
     -H "Authorization: Bearer $SNOWFLAKE_TOKEN" \
     -d '{"statement": "SHOW PROCEDURES LIKE '\''sp_example'\'';"}' \
     "https://$SNOWFLAKE_ACCOUNT/api/v2/statements"
   ```

3. **Insufficient Privileges (391426)**
   ```bash
   # Check current role and privileges
   curl -X POST \
     -H "Authorization: Bearer $SNOWFLAKE_TOKEN" \
     -d '{"statement": "SELECT CURRENT_ROLE(), CURRENT_USER();"}' \
     "https://$SNOWFLAKE_ACCOUNT/api/v2/statements"
   ```

### Debug Mode

Enable verbose curl output:

```bash
# Add -v flag for verbose output
curl -v -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_PAT_TOKEN" \
  ...
```

### Test Connection

```bash
# Simple test query
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_PAT_TOKEN" \
  -d '{"statement": "SELECT CURRENT_TIMESTAMP();"}' \
  "https://your-account.snowflakecomputing.com/api/v2/statements"
```

## Environment Variables Reference

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `SNOWFLAKE_ACCOUNT` | Account identifier | Yes | `mycompany.snowflakecomputing.com` |
| `SNOWFLAKE_USERNAME` | Username | Yes | `john.doe` |
| `SNOWFLAKE_TOKEN` | PAT token (for PAT auth) | Yes* | `ETMsjdT...` |
| `PRIVATE_KEY_PATH` | Private key path (for JWT auth) | Yes* | `./rsa_key.p8` |
| `SNOWFLAKE_DATABASE` | Database name | No | `analytics` |
| `SNOWFLAKE_SCHEMA` | Schema name | No | `public` |
| `SNOWFLAKE_WAREHOUSE` | Warehouse name | No | `compute_wh` |
| `SNOWFLAKE_ROLE` | Role name | No | `data_analyst` |
| `AUTH_METHOD` | Auth method (`pat` or `keypair`) | No | `pat` |
| `OUTPUT_FORMAT` | Output format (`json` or `table`) | No | `json` |

*Required based on authentication method chosen

## Security Notes

- Never commit PAT tokens or private keys to version control
- Use environment variables or secure secret management
- PAT tokens should be rotated regularly
- Private keys should be properly secured with appropriate file permissions
- Consider using temporary credentials in CI/CD environments
