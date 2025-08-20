#!/usr/bin/env python3
"""
Test script to verify Snowflake setup is working correctly.

This script tests both the Python library and the underlying Snowflake configuration
to ensure everything is set up properly for API access.
"""

import os
import sys
from typing import Dict, Any

def load_config() -> Dict[str, str]:
    """Load configuration from environment variables."""
    config = {
        'account': os.getenv('SNOWFLAKE_ACCOUNT'),
        'username': os.getenv('SNOWFLAKE_USERNAME'),
        'token': os.getenv('SNOWFLAKE_TOKEN'),
        'database': os.getenv('SNOWFLAKE_DATABASE'),
        'schema': os.getenv('SNOWFLAKE_SCHEMA'),
        'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE'),
        'role': os.getenv('SNOWFLAKE_ROLE')
    }
    return config

def validate_config(config: Dict[str, str]) -> bool:
    """Validate that required configuration is present."""
    required = ['account', 'username', 'token']
    missing = [key for key in required if not config.get(key)]
    
    if missing:
        print("❌ Missing required environment variables:")
        for var in missing:
            print(f"   - SNOWFLAKE_{var.upper()}")
        print("\nPlease set these variables and try again.")
        return False
    
    print("✅ Required environment variables are set")
    return True

def test_import():
    """Test that the sf_restcalls library can be imported."""
    try:
        from sf_restcalls import SnowflakeClient
        print("✅ sf_restcalls library imported successfully")
        return True
    except ImportError as e:
        print(f"❌ Failed to import sf_restcalls: {e}")
        print("Make sure the library is installed: pip install -e .")
        return False

def test_connection(config: Dict[str, str]) -> bool:
    """Test connection to Snowflake."""
    try:
        from sf_restcalls import SnowflakeClient
        
        print("🔗 Testing Snowflake connection...")
        
        client = SnowflakeClient(
            account=config['account'],
            username=config['username'],
            token=config['token'],
            database=config.get('database'),
            schema=config.get('schema'),
            warehouse=config.get('warehouse'),
            role=config.get('role')
        )
        
        with client:
            # Test basic query
            result = client.execute_query("SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE()")
            
            if result:
                print("✅ Successfully connected to Snowflake")
                print("📊 Current context:")
                if result[0]:
                    print(f"   User: {result[0][0]}")
                    print(f"   Role: {result[0][1]}")
                    print(f"   Database: {result[0][2]}")
                    print(f"   Schema: {result[0][3]}")
                    print(f"   Warehouse: {result[0][4]}")
                return True
            else:
                print("❌ Connection succeeded but no results returned")
                return False
                
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return False

def test_sp_example(config: Dict[str, str]) -> bool:
    """Test calling the sp_example stored procedure."""
    try:
        from sf_restcalls import SnowflakeClient
        
        print("🏃 Testing sp_example stored procedure...")
        
        client = SnowflakeClient(
            account=config['account'],
            username=config['username'],
            token=config['token'],
            database=config.get('database'),
            schema=config.get('schema'),
            warehouse=config.get('warehouse'),
            role=config.get('role')
        )
        
        with client:
            result = client.call_sp_example()
            
            if result:
                print("✅ sp_example executed successfully")
                print(f"📤 Result: {result}")
                return True
            else:
                print("❌ sp_example returned no results")
                return False
                
    except Exception as e:
        print(f"❌ sp_example failed: {e}")
        print("💡 Make sure sp_example procedure exists and user has permissions")
        return False

def test_procedures_exist(config: Dict[str, str]) -> bool:
    """Test that required stored procedures exist."""
    try:
        from sf_restcalls import SnowflakeClient
        
        print("🔍 Checking for stored procedures...")
        
        client = SnowflakeClient(
            account=config['account'],
            username=config['username'],
            token=config['token'],
            database=config.get('database'),
            schema=config.get('schema'),
            warehouse=config.get('warehouse'),
            role=config.get('role')
        )
        
        with client:
            # Check for procedures
            result = client.execute_query("SHOW PROCEDURES LIKE 'sp_%'")
            
            if result:
                print("✅ Found stored procedures:")
                for row in result:
                    print(f"   - {row[1]}")  # Procedure name is typically in second column
                return True
            else:
                print("⚠️  No stored procedures found matching 'sp_%'")
                print("💡 Run quick_user_setup.sql to create example procedures")
                return False
                
    except Exception as e:
        print(f"❌ Failed to check procedures: {e}")
        return False

def main():
    """Main test function."""
    print("🧪 Snowflake Setup Test")
    print("=" * 50)
    
    # Load and validate configuration
    config = load_config()
    if not validate_config(config):
        sys.exit(1)
    
    print(f"🏗️  Testing setup for account: {config['account']}")
    print(f"👤 User: {config['username']}")
    print()
    
    # Run tests
    tests = [
        ("Import Test", test_import),
        ("Connection Test", lambda: test_connection(config)),
        ("Procedures Check", lambda: test_procedures_exist(config)),
        ("sp_example Test", lambda: test_sp_example(config))
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"🧪 {test_name}")
        print("-" * 30)
        
        try:
            if test_func():
                passed += 1
                print("✅ PASSED\n")
            else:
                print("❌ FAILED\n")
        except Exception as e:
            print(f"❌ ERROR: {e}\n")
    
    # Summary
    print("📊 Test Summary")
    print("=" * 50)
    print(f"Passed: {passed}/{total}")
    
    if passed == total:
        print("🎉 All tests passed! Your setup is working correctly.")
        print("\n🚀 You can now use:")
        print("   - Python library: from sf_restcalls import SnowflakeClient")
        print("   - curl scripts: ./snowflake_curl_script.sh sp_example")
        return 0
    else:
        print("⚠️  Some tests failed. Please check the errors above.")
        print("\n💡 Troubleshooting tips:")
        print("   1. Verify environment variables are set correctly")
        print("   2. Check PAT token is valid and not expired")
        print("   3. Ensure user has necessary privileges")
        print("   4. Run setup SQL scripts if procedures are missing")
        print("   5. See SETUP_GUIDE.md for detailed instructions")
        return 1

if __name__ == "__main__":
    sys.exit(main())
