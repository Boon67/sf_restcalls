#!/bin/bash

##############################################################################
# Raw curl Examples for Snowflake Stored Procedures
# 
# These are direct curl commands without wrapper scripts
##############################################################################

echo "Snowflake curl Examples"
echo "======================="
echo

# Set your actual values here
ACCOUNT="your-account.snowflakecomputing.com"
TOKEN="your-pat-token"
DATABASE="your-database"
SCHEMA="your-schema"
WAREHOUSE="your-warehouse"

echo "1. Basic sp_example call (replace variables with your actual values):"
echo
cat << 'EOF'
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_PAT_TOKEN" \
    -H "Accept: application/json" \
    -d '{
        "statement": "CALL sp_example();",
        "database": "YOUR_DATABASE",
        "schema": "YOUR_SCHEMA",
        "warehouse": "YOUR_WAREHOUSE",
        "resultSetMetaData": {
            "format": "json"
        }
    }' \
    "https://YOUR_ACCOUNT.snowflakecomputing.com/api/v2/statements"
EOF

echo
echo "2. Call procedure with parameters:"
echo
cat << 'EOF'
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
        "database": "YOUR_DATABASE",
        "schema": "YOUR_SCHEMA",
        "warehouse": "YOUR_WAREHOUSE"
    }' \
    "https://YOUR_ACCOUNT.snowflakecomputing.com/api/v2/statements"
EOF

echo
echo "3. Asynchronous execution:"
echo
cat << 'EOF'
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_PAT_TOKEN" \
    -H "Accept: application/json" \
    -d '{
        "statement": "CALL long_running_procedure();",
        "asyncExec": true,
        "database": "YOUR_DATABASE",
        "schema": "YOUR_SCHEMA",
        "warehouse": "YOUR_WAREHOUSE"
    }' \
    "https://YOUR_ACCOUNT.snowflakecomputing.com/api/v2/statements"
EOF

echo
echo "4. With timeout and result limits:"
echo
cat << 'EOF'
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_PAT_TOKEN" \
    -H "Accept: application/json" \
    -d '{
        "statement": "CALL sp_example();",
        "timeout": 60,
        "resultSetMetaData": {
            "format": "json",
            "numberOfRowsMaximum": 1000
        },
        "database": "YOUR_DATABASE",
        "schema": "YOUR_SCHEMA",
        "warehouse": "YOUR_WAREHOUSE"
    }' \
    "https://YOUR_ACCOUNT.snowflakecomputing.com/api/v2/statements"
EOF

echo
echo "5. Test connection with simple query:"
echo
cat << 'EOF'
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_PAT_TOKEN" \
    -H "Accept: application/json" \
    -d '{
        "statement": "SELECT CURRENT_TIMESTAMP() as current_time;",
        "database": "YOUR_DATABASE",
        "schema": "YOUR_SCHEMA",
        "warehouse": "YOUR_WAREHOUSE"
    }' \
    "https://YOUR_ACCOUNT.snowflakecomputing.com/api/v2/statements"
EOF

echo
echo "6. Check if procedure exists:"
echo
cat << 'EOF'
curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_PAT_TOKEN" \
    -H "Accept: application/json" \
    -d '{
        "statement": "SHOW PROCEDURES LIKE '\''sp_example'\'';",
        "database": "YOUR_DATABASE",
        "schema": "YOUR_SCHEMA",
        "warehouse": "YOUR_WAREHOUSE"
    }' \
    "https://YOUR_ACCOUNT.snowflakecomputing.com/api/v2/statements"
EOF

echo
echo "Environment Variables Setup:"
echo "export SNOWFLAKE_ACCOUNT=\"your-account.snowflakecomputing.com\""
echo "export SNOWFLAKE_TOKEN=\"your-pat-token\""
echo "export SNOWFLAKE_DATABASE=\"your-database\""
echo "export SNOWFLAKE_SCHEMA=\"your-schema\""
echo "export SNOWFLAKE_WAREHOUSE=\"your-warehouse\""
echo
echo "Then replace YOUR_* placeholders in the curl commands above with the actual values."
echo

# If environment variables are set, show a working example
if [[ -n "$SNOWFLAKE_ACCOUNT" && "$SNOWFLAKE_ACCOUNT" != "your-account.snowflakecomputing.com" ]]; then
    echo "Working example with your environment variables:"
    echo
    echo "curl -X POST \\"
    echo "    -H \"Content-Type: application/json\" \\"
    echo "    -H \"Authorization: Bearer \$SNOWFLAKE_TOKEN\" \\"
    echo "    -H \"Accept: application/json\" \\"
    echo "    -d '{"
    echo "        \"statement\": \"CALL sp_example();\","
    echo "        \"database\": \"$SNOWFLAKE_DATABASE\","
    echo "        \"schema\": \"$SNOWFLAKE_SCHEMA\","
    echo "        \"warehouse\": \"$SNOWFLAKE_WAREHOUSE\""
    echo "    }' \\"
    echo "    \"https://$SNOWFLAKE_ACCOUNT/api/v2/statements\""
fi
