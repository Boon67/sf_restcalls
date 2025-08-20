#!/usr/bin/env python3
"""
Quick demonstration of the sf_restcalls library.

This script shows how to use the library both programmatically and via CLI.
"""

import os
import sys
import subprocess

def check_installation():
    """Check if the library can be imported."""
    try:
        import sf_restcalls
        print(f"✓ sf_restcalls library imported successfully (version {sf_restcalls.__version__})")
        return True
    except ImportError as e:
        print(f"✗ Failed to import sf_restcalls: {e}")
        print("Please install the library first: pip install -e .")
        return False

def show_library_usage():
    """Demonstrate library usage."""
    print("\n" + "="*60)
    print("LIBRARY USAGE EXAMPLE")
    print("="*60)
    
    code_example = '''
from sf_restcalls import SnowflakeClient

# Create client (using environment variables)
client = SnowflakeClient(
    account=os.getenv('SNOWFLAKE_ACCOUNT'),
    username=os.getenv('SNOWFLAKE_USERNAME'),
    token=os.getenv('SNOWFLAKE_TOKEN'),
    warehouse=os.getenv('SNOWFLAKE_WAREHOUSE'),
    database=os.getenv('SNOWFLAKE_DATABASE'),
    schema=os.getenv('SNOWFLAKE_SCHEMA')
)

# Use context manager for automatic connection handling
with client:
    # Call sp_example stored procedure
    results = client.call_sp_example()
    print(f"sp_example returned: {results}")
    
    # Call procedure with parameters
    results = client.call_stored_procedure("my_proc", ["param1", 123])
    print(f"my_proc returned: {results}")
    
    # Execute SQL query
    results = client.execute_query("SELECT CURRENT_TIMESTAMP()")
    print(f"Query returned: {results}")
'''
    
    print("Python Code:")
    print(code_example)

def show_cli_usage():
    """Demonstrate CLI usage."""
    print("\n" + "="*60)
    print("CLI USAGE EXAMPLES")
    print("="*60)
    
    examples = [
        ("Basic sp_example call", "sf-restcalls"),
        ("Call specific procedure", "sf-restcalls --procedure my_procedure"),
        ("Call with parameters", "sf-restcalls --procedure my_proc --parameters 'param1,123,true'"),
        ("Execute SQL query", "sf-restcalls --query 'SELECT CURRENT_TIMESTAMP()'"),
        ("Output as CSV", "sf-restcalls --output csv"),
        ("Save to file", "sf-restcalls --output json --file results.json"),
        ("Verbose logging", "sf-restcalls --verbose"),
        ("Run as module", "python -m sf_restcalls --procedure sp_example"),
    ]
    
    for description, command in examples:
        print(f"\n{description}:")
        print(f"  {command}")

def show_environment_setup():
    """Show environment variable setup."""
    print("\n" + "="*60)
    print("ENVIRONMENT SETUP")
    print("="*60)
    
    print("Set these environment variables for authentication:")
    print()
    
    env_vars = [
        ("SNOWFLAKE_ACCOUNT", "your-account.snowflakecomputing.com", True),
        ("SNOWFLAKE_USERNAME", "your-username", True),
        ("SNOWFLAKE_TOKEN", "your-personal-access-token", True),
        ("SNOWFLAKE_WAREHOUSE", "your-warehouse", False),
        ("SNOWFLAKE_DATABASE", "your-database", False),
        ("SNOWFLAKE_SCHEMA", "your-schema", False),
        ("SNOWFLAKE_ROLE", "your-role", False),
    ]
    
    for var, example, required in env_vars:
        status = "REQUIRED" if required else "optional"
        current = os.getenv(var, "not set")
        print(f"export {var}={example}  # {status} - currently: {current}")

def test_cli_help():
    """Test CLI help command."""
    print("\n" + "="*60)
    print("CLI HELP OUTPUT")
    print("="*60)
    
    try:
        result = subprocess.run([sys.executable, "-m", "sf_restcalls", "--help"], 
                               capture_output=True, text=True, timeout=10)
        print(result.stdout)
    except subprocess.TimeoutExpired:
        print("Help command timed out")
    except Exception as e:
        print(f"Error running help command: {e}")

def main():
    print("Snowflake REST Calls Library - Demo")
    print("="*60)
    
    # Check if library can be imported
    if not check_installation():
        return
    
    # Show usage examples
    show_environment_setup()
    show_library_usage()
    show_cli_usage()
    test_cli_help()
    
    print("\n" + "="*60)
    print("QUICK START")
    print("="*60)
    print("1. Set environment variables (see above)")
    print("2. Install: pip install -e .")
    print("3. Run: sf-restcalls")
    print("4. Or use in Python: from sf_restcalls import SnowflakeClient")
    print()
    print("For more examples, see the examples/ directory:")
    print("- examples/basic_usage.py")
    print("- examples/with_parameters.py") 
    print("- examples/error_handling.py")

if __name__ == '__main__':
    main()
