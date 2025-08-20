#!/bin/bash

##############################################################################
# Snowflake Stored Procedure Call via curl Script
# 
# This script demonstrates how to call stored procedures in Snowflake using
# the Snowflake SQL API with curl commands.
#
# Supports two authentication methods:
# 1. Key-pair authentication (JWT)
# 2. Personal Access Token (PAT) - OAuth
##############################################################################

set -e  # Exit on any error

# Configuration - Update these values for your environment
SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-your-account.snowflakecomputing.com}"
SNOWFLAKE_USERNAME="${SNOWFLAKE_USERNAME:-your-username}"
SNOWFLAKE_DATABASE="${SNOWFLAKE_DATABASE:-your-database}"
SNOWFLAKE_SCHEMA="${SNOWFLAKE_SCHEMA:-your-schema}"
SNOWFLAKE_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-your-warehouse}"
SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-your-role}"

# Stored procedure to call
PROCEDURE_NAME="${1:-sp_example}"
PROCEDURE_PARAMS="${2:-}"

# Authentication method (keypair or pat)
AUTH_METHOD="${AUTH_METHOD:-pat}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Function to validate required environment variables
validate_config() {
    local missing_vars=()
    
    if [[ "$SNOWFLAKE_ACCOUNT" == "your-account.snowflakecomputing.com" ]]; then
        missing_vars+=("SNOWFLAKE_ACCOUNT")
    fi
    
    if [[ "$SNOWFLAKE_USERNAME" == "your-username" ]]; then
        missing_vars+=("SNOWFLAKE_USERNAME")
    fi
    
    if [[ "$AUTH_METHOD" == "pat" && -z "$SNOWFLAKE_TOKEN" ]]; then
        missing_vars+=("SNOWFLAKE_TOKEN")
    fi
    
    if [[ "$AUTH_METHOD" == "keypair" && ! -f "$PRIVATE_KEY_PATH" ]]; then
        missing_vars+=("PRIVATE_KEY_PATH (file not found)")
    fi
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required configuration:"
        printf '%s\n' "${missing_vars[@]}" | sed 's/^/  - /'
        echo
        print_usage
        exit 1
    fi
}

# Function to print usage information
print_usage() {
    cat << EOF
Usage: $0 [PROCEDURE_NAME] [PARAMETERS]

Examples:
  # Call sp_example with no parameters
  $0

  # Call sp_example with no parameters (explicit)
  $0 sp_example

  # Call procedure with parameters
  $0 my_procedure "param1,param2,123"

Environment Variables:
  Required:
    SNOWFLAKE_ACCOUNT    - Snowflake account identifier
    SNOWFLAKE_USERNAME   - Snowflake username
    
  Authentication (choose one):
    SNOWFLAKE_TOKEN      - Personal Access Token (for PAT auth)
    PRIVATE_KEY_PATH     - Path to private key file (for key-pair auth)
    
  Optional:
    SNOWFLAKE_DATABASE   - Database name (default: your-database)
    SNOWFLAKE_SCHEMA     - Schema name (default: your-schema)
    SNOWFLAKE_WAREHOUSE  - Warehouse name (default: your-warehouse)
    SNOWFLAKE_ROLE       - Role name (default: your-role)
    AUTH_METHOD          - Authentication method: 'pat' or 'keypair' (default: pat)
    OUTPUT_FORMAT        - Output format: 'json' or 'table' (default: json)

Examples with environment variables:
  export SNOWFLAKE_ACCOUNT="mycompany.snowflakecomputing.com"
  export SNOWFLAKE_USERNAME="john.doe"
  export SNOWFLAKE_TOKEN="your-pat-token"
  export SNOWFLAKE_DATABASE="analytics"
  export SNOWFLAKE_SCHEMA="public"
  export SNOWFLAKE_WAREHOUSE="compute_wh"
  
  $0 sp_example
EOF
}

# Function to generate JWT for key-pair authentication
generate_jwt() {
    local private_key_path="$1"
    local username="$2"
    local account="$3"
    
    print_status "Generating JWT for key-pair authentication..."
    
    # Check if private key exists
    if [[ ! -f "$private_key_path" ]]; then
        print_error "Private key file not found: $private_key_path"
        exit 1
    fi
    
    # Use Python to generate JWT (requires PyJWT library)
    python3 -c "
import jwt
import time
from cryptography.hazmat.primitives import serialization

# Read private key
with open('$private_key_path', 'rb') as key_file:
    private_key = serialization.load_pem_private_key(
        key_file.read(),
        password=None
    )

# Create JWT payload
now = int(time.time())
payload = {
    'iss': f'$username.$account',
    'sub': f'$username.$account', 
    'iat': now,
    'exp': now + 3600  # Token expires in 1 hour
}

# Generate JWT
token = jwt.encode(payload, private_key, algorithm='RS256')
print(token)
" 2>/dev/null || {
        print_error "Failed to generate JWT. Make sure PyJWT and cryptography are installed:"
        print_error "pip install PyJWT cryptography"
        exit 1
    }
}

# Function to create request body
create_request_body() {
    local procedure_name="$1"
    local procedure_params="$2"
    
    # Build the CALL statement
    local call_statement
    if [[ -n "$procedure_params" ]]; then
        # Parse parameters (simple comma-separated for now)
        call_statement="CALL ${procedure_name}(${procedure_params});"
    else
        call_statement="CALL ${procedure_name}();"
    fi
    
    # Create JSON request body
    cat << EOF
{
  "statement": "$call_statement",
  "resultSetMetaData": {
    "format": "json"
  }
$(if [[ -n "$SNOWFLAKE_DATABASE" && "$SNOWFLAKE_DATABASE" != "your-database" ]]; then echo ",  \"database\": \"$SNOWFLAKE_DATABASE\""; fi)
$(if [[ -n "$SNOWFLAKE_SCHEMA" && "$SNOWFLAKE_SCHEMA" != "your-schema" ]]; then echo ",  \"schema\": \"$SNOWFLAKE_SCHEMA\""; fi)
$(if [[ -n "$SNOWFLAKE_WAREHOUSE" && "$SNOWFLAKE_WAREHOUSE" != "your-warehouse" ]]; then echo ",  \"warehouse\": \"$SNOWFLAKE_WAREHOUSE\""; fi)
$(if [[ -n "$SNOWFLAKE_ROLE" && "$SNOWFLAKE_ROLE" != "your-role" ]]; then echo ",  \"role\": \"$SNOWFLAKE_ROLE\""; fi)
}
EOF
}

# Function to make the API call
call_snowflake_api() {
    local auth_header="$1"
    local request_body="$2"
    local api_url="https://${SNOWFLAKE_ACCOUNT}/api/v2/statements"
    
    print_status "Calling Snowflake API..."
    print_status "URL: $api_url"
    print_status "Procedure: $PROCEDURE_NAME"
    
    # Create temporary file for request body
    local temp_file=$(mktemp)
    echo "$request_body" > "$temp_file"
    
    # Make the API call
    local response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "User-Agent: snowflake-curl-script/1.0" \
        -H "$auth_header" \
        -d "@$temp_file" \
        "$api_url")
    
    # Clean up temporary file
    rm -f "$temp_file"
    
    # Extract HTTP status code and response body
    local http_code=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | head -n -1)
    
    print_status "HTTP Status Code: $http_code"
    
    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        print_status "API call successful!"
        
        # Format output based on OUTPUT_FORMAT
        if [[ "${OUTPUT_FORMAT:-json}" == "table" ]]; then
            format_table_output "$response_body"
        else
            echo "$response_body" | python3 -m json.tool 2>/dev/null || echo "$response_body"
        fi
    else
        print_error "API call failed with status $http_code"
        echo "$response_body" | python3 -m json.tool 2>/dev/null || echo "$response_body"
        exit 1
    fi
}

# Function to format output as a table
format_table_output() {
    local json_response="$1"
    
    # Extract and display results in table format using Python
    python3 -c "
import json
import sys

try:
    data = json.loads('$json_response')
    
    # Check if we have data
    if 'data' in data and data['data']:
        rows = data['data']
        
        # Get column names from resultSetMetaData if available
        if 'resultSetMetaData' in data and 'rowType' in data['resultSetMetaData']:
            columns = [col['name'] for col in data['resultSetMetaData']['rowType']]
        else:
            # Fallback: use indices as column names
            columns = [f'Col_{i}' for i in range(len(rows[0]) if rows else 0)]
        
        # Print header
        print('\\t'.join(columns))
        print('-' * (len('\\t'.join(columns)) + len(columns) * 8))
        
        # Print rows
        for row in rows:
            print('\\t'.join(str(cell) if cell is not None else 'NULL' for cell in row))
    else:
        print('No data returned from stored procedure')
        
except json.JSONDecodeError:
    print('Failed to parse JSON response')
    print('$json_response')
except Exception as e:
    print(f'Error formatting output: {e}')
    print('$json_response')
" || echo "$json_response"
}

# Main execution
main() {
    print_header "=============================================="
    print_header "  Snowflake Stored Procedure curl Script"
    print_header "=============================================="
    
    # Show usage if help requested
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        print_usage
        exit 0
    fi
    
    # Validate configuration
    validate_config
    
    print_status "Configuration:"
    print_status "  Account: $SNOWFLAKE_ACCOUNT"
    print_status "  Username: $SNOWFLAKE_USERNAME"
    print_status "  Database: $SNOWFLAKE_DATABASE"
    print_status "  Schema: $SNOWFLAKE_SCHEMA"
    print_status "  Warehouse: $SNOWFLAKE_WAREHOUSE"
    print_status "  Role: $SNOWFLAKE_ROLE"
    print_status "  Auth Method: $AUTH_METHOD"
    print_status "  Procedure: $PROCEDURE_NAME"
    if [[ -n "$PROCEDURE_PARAMS" ]]; then
        print_status "  Parameters: $PROCEDURE_PARAMS"
    fi
    echo
    
    # Create request body
    local request_body=$(create_request_body "$PROCEDURE_NAME" "$PROCEDURE_PARAMS")
    print_status "Request body:"
    echo "$request_body" | python3 -m json.tool 2>/dev/null || echo "$request_body"
    echo
    
    # Set up authentication
    local auth_header
    if [[ "$AUTH_METHOD" == "keypair" ]]; then
        local jwt_token=$(generate_jwt "$PRIVATE_KEY_PATH" "$SNOWFLAKE_USERNAME" "${SNOWFLAKE_ACCOUNT%%.*}")
        auth_header="Authorization: Bearer $jwt_token"
    elif [[ "$AUTH_METHOD" == "pat" ]]; then
        auth_header="Authorization: Bearer $SNOWFLAKE_TOKEN"
    else
        print_error "Invalid authentication method: $AUTH_METHOD"
        print_error "Use 'keypair' or 'pat'"
        exit 1
    fi
    
    # Make the API call
    call_snowflake_api "$auth_header" "$request_body"
}

# Run the script
main "$@"
