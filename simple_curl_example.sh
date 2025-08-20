#!/bin/bash

##############################################################################
# Simple Snowflake curl Example
# 
# Basic example of calling sp_example stored procedure using curl
##############################################################################

# Configuration - Set these environment variables
SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-your-account.snowflakecomputing.com}"
SNOWFLAKE_TOKEN="${SNOWFLAKE_TOKEN:-your-pat-token}"
SNOWFLAKE_DATABASE="${SNOWFLAKE_DATABASE:-your-database}"
SNOWFLAKE_SCHEMA="${SNOWFLAKE_SCHEMA:-your-schema}"
SNOWFLAKE_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-your-warehouse}"

# Validate required variables
if [[ "$SNOWFLAKE_ACCOUNT" == "your-account.snowflakecomputing.com" ]]; then
    echo "Error: Please set SNOWFLAKE_ACCOUNT environment variable"
    exit 1
fi

if [[ "$SNOWFLAKE_TOKEN" == "your-pat-token" ]]; then
    echo "Error: Please set SNOWFLAKE_TOKEN environment variable"
    exit 1
fi

# API endpoint
API_URL="https://${SNOWFLAKE_ACCOUNT}/api/v2/statements"

echo "Calling sp_example stored procedure..."
echo "Account: $SNOWFLAKE_ACCOUNT"
echo "API URL: $API_URL"
echo

# Call the stored procedure
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SNOWFLAKE_TOKEN" \
    -H "Accept: application/json" \
    -H "User-Agent: simple-curl-example/1.0" \
    -d "{
        \"statement\": \"CALL sp_example();\",
        \"database\": \"$SNOWFLAKE_DATABASE\",
        \"schema\": \"$SNOWFLAKE_SCHEMA\",
        \"warehouse\": \"$SNOWFLAKE_WAREHOUSE\",
        \"resultSetMetaData\": {
            \"format\": \"json\"
        }
    }" \
    "$API_URL" | python3 -m json.tool

echo
echo "Done!"
