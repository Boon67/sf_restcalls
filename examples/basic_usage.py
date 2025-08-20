#!/usr/bin/env python3
"""
Basic usage example for the sf_restcalls library.

This example demonstrates:
1. Creating a Snowflake client with PAT token
2. Connecting to Snowflake
3. Calling the sp_example stored procedure
4. Handling results
"""

import os
from sf_restcalls import SnowflakeClient, SnowflakeConnectionError, AuthenticationError

def main():
    # Configuration - preferably from environment variables
    config = {
        'account': os.getenv('SNOWFLAKE_ACCOUNT', 'your-account.snowflakecomputing.com'),
        'username': os.getenv('SNOWFLAKE_USERNAME', 'your-username'),
        'token': os.getenv('SNOWFLAKE_TOKEN', 'your-pat-token'),
        'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE', 'your-warehouse'),
        'database': os.getenv('SNOWFLAKE_DATABASE', 'your-database'),
        'schema': os.getenv('SNOWFLAKE_SCHEMA', 'your-schema'),
    }
    
    try:
        # Create the client
        client = SnowflakeClient(**config)
        
        # Method 1: Using context manager (recommended)
        print("=== Using Context Manager ===")
        with client:
            # Call sp_example stored procedure
            results = client.call_sp_example()
            print(f"sp_example returned {len(results)} rows:")
            for i, row in enumerate(results[:5]):  # Show first 5 rows
                print(f"Row {i+1}: {row}")
            
            if len(results) > 5:
                print(f"... and {len(results) - 5} more rows")
        
        # Method 2: Manual connection management
        print("\n=== Manual Connection Management ===")
        client.connect()
        try:
            # Call the stored procedure
            results = client.call_stored_procedure('sp_example')
            print(f"Results: {results}")
        finally:
            client.disconnect()
            
    except AuthenticationError as e:
        print(f"Authentication failed: {e}")
        print("Please check your PAT token and credentials.")
    except SnowflakeConnectionError as e:
        print(f"Connection failed: {e}")
        print("Please check your network connection and Snowflake account details.")
    except Exception as e:
        print(f"Unexpected error: {e}")

if __name__ == '__main__':
    print("Snowflake REST Calls - Basic Usage Example")
    print("=========================================")
    print()
    print("Make sure to set these environment variables:")
    print("- SNOWFLAKE_ACCOUNT")
    print("- SNOWFLAKE_USERNAME") 
    print("- SNOWFLAKE_TOKEN")
    print("- SNOWFLAKE_WAREHOUSE")
    print("- SNOWFLAKE_DATABASE")
    print("- SNOWFLAKE_SCHEMA")
    print()
    
    main()
