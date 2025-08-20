#!/usr/bin/env python3
"""
Example demonstrating comprehensive error handling.

This example shows:
1. How to handle different types of errors
2. Proper error recovery strategies
3. Logging and debugging techniques
"""

import os
import logging
from sf_restcalls import (
    SnowflakeClient, 
    SnowflakeConnectionError, 
    AuthenticationError,
    StoredProcedureError,
    ConfigurationError
)

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def demonstrate_connection_errors():
    """Demonstrate connection error handling."""
    print("=== Connection Error Handling ===")
    
    # Test with invalid account
    try:
        client = SnowflakeClient(
            account="invalid-account.snowflakecomputing.com",
            username="test",
            token="invalid-token"
        )
        client.connect()
    except AuthenticationError as e:
        print(f"✓ Caught authentication error: {e}")
    except SnowflakeConnectionError as e:
        print(f"✓ Caught connection error: {e}")
    except Exception as e:
        print(f"✓ Caught unexpected error: {e}")

def demonstrate_configuration_errors():
    """Demonstrate configuration error handling."""
    print("\n=== Configuration Error Handling ===")
    
    # Test missing required parameters
    try:
        client = SnowflakeClient(
            account="",  # Empty account
            username="test",
            token="test"
        )
        client.connect()
    except Exception as e:
        print(f"✓ Caught configuration error: {e}")

def demonstrate_procedure_errors():
    """Demonstrate stored procedure error handling."""
    print("\n=== Stored Procedure Error Handling ===")
    
    config = {
        'account': os.getenv('SNOWFLAKE_ACCOUNT', 'your-account.snowflakecomputing.com'),
        'username': os.getenv('SNOWFLAKE_USERNAME', 'your-username'),
        'token': os.getenv('SNOWFLAKE_TOKEN', 'your-pat-token'),
        'warehouse': os.getenv('SNOWFLAKE_WAREHOUSE'),
        'database': os.getenv('SNOWFLAKE_DATABASE'),
        'schema': os.getenv('SNOWFLAKE_SCHEMA'),
    }
    
    # Skip if no real credentials
    if not all([config['account'].startswith('your-') is False, 
                config['username'].startswith('your-') is False,
                config['token'].startswith('your-') is False]):
        print("Skipping procedure error demo - no real credentials provided")
        return
    
    try:
        client = SnowflakeClient(**config)
        with client:
            # Test calling non-existent procedure
            try:
                results = client.call_stored_procedure("non_existent_procedure")
                print(f"Unexpected success: {results}")
            except StoredProcedureError as e:
                print(f"✓ Caught procedure error: {e}")
            
            # Test calling procedure with wrong parameters
            try:
                # Assuming sp_example expects certain parameters
                results = client.call_stored_procedure("sp_example", ["wrong", "parameter", "count"])
                print(f"Results: {results}")
            except StoredProcedureError as e:
                print(f"✓ Caught parameter error: {e}")
                
    except Exception as e:
        print(f"Connection failed (expected if no real credentials): {e}")

def demonstrate_recovery_strategies():
    """Demonstrate error recovery strategies."""
    print("\n=== Recovery Strategies ===")
    
    # Strategy 1: Retry with exponential backoff
    def retry_with_backoff(func, max_retries=3, base_delay=1):
        """Retry function with exponential backoff."""
        import time
        
        for attempt in range(max_retries):
            try:
                return func()
            except Exception as e:
                if attempt == max_retries - 1:
                    raise e
                
                delay = base_delay * (2 ** attempt)
                print(f"Attempt {attempt + 1} failed: {e}")
                print(f"Retrying in {delay} seconds...")
                time.sleep(delay)
    
    # Strategy 2: Graceful degradation
    def call_procedure_with_fallback(client, primary_proc, fallback_proc, params=None):
        """Try primary procedure, fall back to secondary if it fails."""
        try:
            return client.call_stored_procedure(primary_proc, params)
        except StoredProcedureError as e:
            logger.warning(f"Primary procedure {primary_proc} failed: {e}")
            logger.info(f"Trying fallback procedure {fallback_proc}")
            return client.call_stored_procedure(fallback_proc, params)
    
    # Strategy 3: Circuit breaker pattern
    class CircuitBreaker:
        def __init__(self, failure_threshold=5, recovery_timeout=60):
            self.failure_threshold = failure_threshold
            self.recovery_timeout = recovery_timeout
            self.failure_count = 0
            self.last_failure_time = None
            self.state = "CLOSED"  # CLOSED, OPEN, HALF_OPEN
        
        def call(self, func, *args, **kwargs):
            if self.state == "OPEN":
                if time.time() - self.last_failure_time < self.recovery_timeout:
                    raise Exception("Circuit breaker is OPEN")
                else:
                    self.state = "HALF_OPEN"
            
            try:
                result = func(*args, **kwargs)
                self.failure_count = 0
                self.state = "CLOSED"
                return result
            except Exception as e:
                self.failure_count += 1
                self.last_failure_time = time.time()
                
                if self.failure_count >= self.failure_threshold:
                    self.state = "OPEN"
                
                raise e
    
    print("✓ Recovery strategies implemented (retry, fallback, circuit breaker)")

def main():
    print("Snowflake REST Calls - Error Handling Examples")
    print("==============================================")
    
    demonstrate_connection_errors()
    demonstrate_configuration_errors()
    demonstrate_procedure_errors()
    demonstrate_recovery_strategies()
    
    print("\n=== Best Practices Summary ===")
    print("1. Always use try-catch blocks for specific exception types")
    print("2. Implement retry logic for transient errors")
    print("3. Use circuit breakers for external service calls")
    print("4. Provide fallback mechanisms when possible")
    print("5. Log errors with appropriate detail levels")
    print("6. Validate configuration before attempting connections")
    print("7. Use context managers for resource cleanup")

if __name__ == '__main__':
    main()
