# Snowflake REST Calls Library

A Python library for connecting to Snowflake using Personal Access Tokens (PAT) and executing stored procedures with CLI support.

## Features

- Connect to Snowflake using PAT token authentication
- Execute stored procedures with parameters
- Execute arbitrary SQL queries
- Command-line interface for easy automation
- Multiple output formats (JSON, CSV, table)
- Environment variable configuration
- Comprehensive error handling and logging

## Installation

### From Source

```bash
git clone <your-repo-url>
cd sf_restcalls
pip install -e .
```

### From PyPI (when published)

```bash
pip install sf-restcalls
```

## Setup

### Snowflake User Account Setup

Before using the library, you need to set up a Snowflake user account with PAT token authentication:

1. **Quick Setup**: Run the provided SQL script
   ```sql
   -- Execute in Snowflake as ACCOUNTADMIN
   @quick_user_setup.sql
   ```

2. **Generate PAT Token**: Create a Personal Access Token for the user

3. **Configure Environment**: Set environment variables with your credentials

See `SETUP_GUIDE.md` for comprehensive setup instructions including:
- Complete user account creation
- PAT token generation
- Database and warehouse setup
- Stored procedure creation
- Testing and troubleshooting

### Available SQL Scripts
- `quick_user_setup.sql` - Minimal setup for testing
- `setup_user_with_pat.sql` - Comprehensive production setup
- `SETUP_GUIDE.md` - Detailed setup documentation

## Quick Start

### As a Python Library

```python
from sf_restcalls import SnowflakeClient

# Create client
client = SnowflakeClient(
    account="your-account.snowflakecomputing.com",
    username="your-username",
    token="your-pat-token",
    warehouse="your-warehouse",
    database="your-database",
    schema="your-schema"
)

# Using context manager (recommended)
with client:
    # Call sp_example stored procedure
    results = client.call_sp_example()
    print(results)
    
    # Call any stored procedure with parameters
    results = client.call_stored_procedure("my_procedure", ["param1", "param2"])
    print(results)
    
    # Execute SQL query
    results = client.execute_query("SELECT * FROM my_table LIMIT 10")
    print(results)
```

### Using the CLI

#### Environment Variables (Recommended)

Set up your credentials using environment variables:

```bash
export SNOWFLAKE_ACCOUNT="your-account.snowflakecomputing.com"
export SNOWFLAKE_USERNAME="your-username"
export SNOWFLAKE_TOKEN="your-pat-token"
export SNOWFLAKE_WAREHOUSE="your-warehouse"
export SNOWFLAKE_DATABASE="your-database"
export SNOWFLAKE_SCHEMA="your-schema"
```

Then run commands:

```bash
# Call sp_example stored procedure
sf-restcalls

# Call specific stored procedure
sf-restcalls --procedure my_procedure

# Call procedure with parameters
sf-restcalls --procedure my_procedure --parameters "param1,param2,123"

# Execute SQL query
sf-restcalls --query "SELECT * FROM my_table LIMIT 10"

# Output as CSV to file
sf-restcalls --output csv --file results.csv

# Verbose logging
sf-restcalls --verbose
```

#### Command Line Arguments

You can also provide credentials via command line:

```bash
sf-restcalls \
  --account your-account.snowflakecomputing.com \
  --username your-username \
  --token your-pat-token \
  --warehouse your-warehouse \
  --database your-database \
  --schema your-schema \
  --procedure sp_example
```

#### Running as Python Module

```bash
python -m sf_restcalls --procedure sp_example
```

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier | Yes |
| `SNOWFLAKE_USERNAME` | Snowflake username | Yes |
| `SNOWFLAKE_TOKEN` | Personal Access Token | Yes |
| `SNOWFLAKE_WAREHOUSE` | Snowflake warehouse | No |
| `SNOWFLAKE_DATABASE` | Snowflake database | No |
| `SNOWFLAKE_SCHEMA` | Snowflake schema | No |
| `SNOWFLAKE_ROLE` | Snowflake role | No |

### Command Line Options

```
usage: sf-restcalls [-h] [--account ACCOUNT] [--username USERNAME] [--token TOKEN]
                    [--warehouse WAREHOUSE] [--database DATABASE] [--schema SCHEMA]
                    [--role ROLE] [--procedure PROCEDURE] [--parameters PARAMETERS]
                    [--query QUERY] [--output {json,table,csv}] [--file FILE] [--verbose]

Snowflake REST Calls CLI - Connect to Snowflake and execute stored procedures

optional arguments:
  -h, --help            show this help message and exit
  --account ACCOUNT     Snowflake account identifier (or set SNOWFLAKE_ACCOUNT env var)
  --username USERNAME   Snowflake username (or set SNOWFLAKE_USERNAME env var)
  --token TOKEN         Personal Access Token (or set SNOWFLAKE_TOKEN env var)
  --warehouse WAREHOUSE Snowflake warehouse (or set SNOWFLAKE_WAREHOUSE env var)
  --database DATABASE   Snowflake database (or set SNOWFLAKE_DATABASE env var)
  --schema SCHEMA       Snowflake schema (or set SNOWFLAKE_SCHEMA env var)
  --role ROLE           Snowflake role (or set SNOWFLAKE_ROLE env var)
  --procedure PROCEDURE, -p PROCEDURE
                        Name of stored procedure to call (default: sp_example)
  --parameters PARAMETERS
                        Comma-separated parameters to pass to the stored procedure
  --query QUERY, -q QUERY
                        SQL query to execute instead of calling stored procedure
  --output {json,table,csv}, -o {json,table,csv}
                        Output format (default: json)
  --file FILE, -f FILE  Write output to file instead of stdout
  --verbose, -v         Enable verbose logging
```

## Examples

### Python Library Examples

See the `examples/` directory for complete examples:

- `examples/basic_usage.py` - Basic library usage
- `examples/with_parameters.py` - Calling procedures with parameters
- `examples/error_handling.py` - Error handling examples

### CLI Examples

```bash
# Basic sp_example call
sf-restcalls

# Call with parameters (supports JSON values)
sf-restcalls --procedure my_proc --parameters "string_param,123,true"

# Complex parameters with JSON
sf-restcalls --procedure my_proc --parameters '"complex string","nested,value",{"key":"value"}'

# SQL query with table output
sf-restcalls --query "SHOW TABLES" --output table

# Save results to CSV file
sf-restcalls --procedure analytics_report --output csv --file report.csv

# Verbose logging for debugging
sf-restcalls --procedure sp_example --verbose
```

## Error Handling

The library provides specific exception types:

- `SnowflakeConnectionError` - Connection issues
- `AuthenticationError` - Authentication failures
- `StoredProcedureError` - Procedure execution errors
- `ConfigurationError` - Configuration issues

## Development

### Setup Development Environment

```bash
git clone <repo-url>
cd sf_restcalls
pip install -e .
pip install pytest pytest-cov  # for testing
```

### Running Tests

```bash
pytest tests/
```

## Requirements

- Python 3.8+
- snowflake-connector-python >= 3.6.0

## License

MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## curl Scripts

In addition to the Python library, this repository includes curl scripts for calling Snowflake stored procedures directly via HTTP:

### Available Scripts

1. **`snowflake_curl_script.sh`** - Comprehensive script with full feature support
2. **`simple_curl_example.sh`** - Simple example for basic usage
3. **`raw_curl_examples.sh`** - Raw curl command examples

### Quick curl Usage

```bash
# Set environment variables
export SNOWFLAKE_ACCOUNT="your-account.snowflakecomputing.com"
export SNOWFLAKE_USERNAME="your-username"
export SNOWFLAKE_TOKEN="your-pat-token"
export SNOWFLAKE_DATABASE="your-database"
export SNOWFLAKE_SCHEMA="your-schema"
export SNOWFLAKE_WAREHOUSE="your-warehouse"

# Call sp_example using the comprehensive script
./snowflake_curl_script.sh

# Call with parameters
./snowflake_curl_script.sh my_procedure "param1,param2,123"

# Simple example
./simple_curl_example.sh
```

### Raw curl Example

```bash
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
```

### Authentication Methods

- **PAT Token** (Recommended): Use Personal Access Token
- **Key-pair Authentication**: Use RSA key pairs with JWT

See `curl_examples.md` for comprehensive documentation and examples.

## Security

This library handles sensitive authentication credentials. Please review the security guidelines:

- See `SECURITY.md` for comprehensive security best practices
- Never commit authentication tokens or private keys to version control
- Use environment variables for all sensitive configuration
- The `.gitignore` file is configured to prevent accidental commits of sensitive files

**Important Files to Keep Secure:**
- Private keys (`*.p8`, `*.pem`)
- PAT tokens and credentials
- Configuration files with connection details
- Environment files (`.env`)

## Support

For issues and questions, please open a GitHub issue.
