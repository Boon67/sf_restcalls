#!/usr/bin/env python3
"""
Example showing how to call stored procedures with parameters.

This example demonstrates:
1. Calling stored procedures with different parameter types
2. Handling various data types
3. Error handling for procedure calls
"""

import os
from datetime import datetime, date
from sf_restcalls import SnowflakeClient, StoredProcedureError

def main():
    # Configuration
    config = {
        'account': os.getenv('SNOWFLAKE_ACCOUNT', 'your-account.snowflakecomputing.com'),
        'username': os.getenv('SNOWFLAKE_USERNAME', 'your-username'),
        'token': os.getenv('SNOWFLAKE_TOKEN', 'your-pat-token'),
        'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE', 'your-warehouse'),
        'database': os.getenv('SNOWFLAKE_DATABASE', 'your-database'),
        'schema': os.getenv('SNOWFLAKE_SCHEMA', 'your-schema'),
    }
    
    client = SnowflakeClient(**config)
    
    try:
        with client:
            # Example 1: Call sp_example with no parameters
            print("=== Calling sp_example (no parameters) ===")
            results = client.call_sp_example()
            print(f"Results: {results}")
            
            # Example 2: Call sp_example with parameters
            print("\n=== Calling sp_example with parameters ===")
            params = ["test_string", 123, True]
            results = client.call_sp_example(params)
            print(f"Results with parameters {params}: {results}")
            
            # Example 3: Call other stored procedures with various parameter types
            print("\n=== Calling procedures with different parameter types ===")
            
            # String parameter
            try:
                results = client.call_stored_procedure("my_string_proc", ["hello world"])
                print(f"String procedure results: {results}")
            except StoredProcedureError as e:
                print(f"String procedure not found (expected): {e}")
            
            # Numeric parameters
            try:
                results = client.call_stored_procedure("my_math_proc", [42, 3.14159])
                print(f"Math procedure results: {results}")
            except StoredProcedureError as e:
                print(f"Math procedure not found (expected): {e}")
            
            # Date parameter
            try:
                today = date.today()
                results = client.call_stored_procedure("my_date_proc", [today])
                print(f"Date procedure results: {results}")
            except StoredProcedureError as e:
                print(f"Date procedure not found (expected): {e}")
            
            # Mixed parameters
            try:
                mixed_params = [
                    "report_name",
                    datetime.now(),
                    100,
                    True,
                    None  # NULL value
                ]
                results = client.call_stored_procedure("my_report_proc", mixed_params)
                print(f"Mixed parameters procedure results: {results}")
            except StoredProcedureError as e:
                print(f"Mixed parameters procedure not found (expected): {e}")
                
            # Example 4: Execute a query instead of stored procedure
            print("\n=== Executing SQL query ===")
            try:
                results = client.execute_query("SELECT CURRENT_TIMESTAMP() AS current_time")
                print(f"Query results: {results}")
            except Exception as e:
                print(f"Query error: {e}")
                
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    print("Snowflake REST Calls - Parameters Example")
    print("========================================")
    print()
    main()
