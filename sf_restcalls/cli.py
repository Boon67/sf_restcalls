"""
Command Line Interface for the Snowflake REST Calls library.
"""

import argparse
import json
import sys
import logging
import os
from typing import List, Any, Optional
from .snowflake_client import SnowflakeClient
from .exceptions import (
    SnowflakeConnectionError, 
    StoredProcedureError, 
    AuthenticationError,
    ConfigurationError
)


def setup_logging(verbose: bool = False) -> None:
    """Set up logging configuration."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )


def parse_parameters(param_string: Optional[str]) -> Optional[List[Any]]:
    """
    Parse parameter string into a list of values.
    
    Args:
        param_string: Comma-separated string of parameters
        
    Returns:
        List of parameters or None if empty
    """
    if not param_string:
        return None
    
    # Split by comma and strip whitespace
    params = [param.strip() for param in param_string.split(',')]
    
    # Try to convert to appropriate types
    parsed_params = []
    for param in params:
        # Try to parse as JSON first (for complex types)
        try:
            parsed_param = json.loads(param)
            parsed_params.append(parsed_param)
        except json.JSONDecodeError:
            # If not JSON, treat as string
            parsed_params.append(param)
    
    return parsed_params


def load_config_from_env() -> dict:
    """Load configuration from environment variables."""
    config = {}
    
    env_mapping = {
        'SNOWFLAKE_ACCOUNT': 'account',
        'SNOWFLAKE_USERNAME': 'username', 
        'SNOWFLAKE_TOKEN': 'token',
        'SNOWFLAKE_WAREHOUSE': 'warehouse',
        'SNOWFLAKE_DATABASE': 'database',
        'SNOWFLAKE_SCHEMA': 'schema',
        'SNOWFLAKE_ROLE': 'role'
    }
    
    for env_var, config_key in env_mapping.items():
        value = os.getenv(env_var)
        if value:
            config[config_key] = value
    
    return config


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description='Snowflake REST Calls CLI - Connect to Snowflake and execute stored procedures'
    )
    
    # Connection parameters
    parser.add_argument('--account', 
                       help='Snowflake account identifier (or set SNOWFLAKE_ACCOUNT env var)')
    parser.add_argument('--username', 
                       help='Snowflake username (or set SNOWFLAKE_USERNAME env var)')
    parser.add_argument('--token', 
                       help='Personal Access Token (or set SNOWFLAKE_TOKEN env var)')
    parser.add_argument('--warehouse', 
                       help='Snowflake warehouse (or set SNOWFLAKE_WAREHOUSE env var)')
    parser.add_argument('--database', 
                       help='Snowflake database (or set SNOWFLAKE_DATABASE env var)')
    parser.add_argument('--schema', 
                       help='Snowflake schema (or set SNOWFLAKE_SCHEMA env var)')
    parser.add_argument('--role', 
                       help='Snowflake role (or set SNOWFLAKE_ROLE env var)')
    
    # Action parameters
    parser.add_argument('--procedure', '-p',
                       default='sp_example',
                       help='Name of stored procedure to call (default: sp_example)')
    parser.add_argument('--parameters', 
                       help='Comma-separated parameters to pass to the stored procedure')
    parser.add_argument('--query', '-q',
                       help='SQL query to execute instead of calling stored procedure')
    
    # Output options
    parser.add_argument('--output', '-o',
                       choices=['json', 'table', 'csv'],
                       default='json',
                       help='Output format (default: json)')
    parser.add_argument('--file', '-f',
                       help='Write output to file instead of stdout')
    
    # Other options
    parser.add_argument('--verbose', '-v',
                       action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    # Set up logging
    setup_logging(args.verbose)
    logger = logging.getLogger(__name__)
    
    try:
        # Load configuration from environment variables
        config = load_config_from_env()
        
        # Override with command line arguments
        for key in ['account', 'username', 'token', 'warehouse', 'database', 'schema', 'role']:
            value = getattr(args, key)
            if value:
                config[key] = value
        
        # Validate required parameters
        required_params = ['account', 'username', 'token']
        missing_params = [param for param in required_params if param not in config]
        
        if missing_params:
            raise ConfigurationError(
                f"Missing required parameters: {', '.join(missing_params)}. "
                f"Provide them via command line arguments or environment variables."
            )
        
        # Create client
        client = SnowflakeClient(
            account=config['account'],
            username=config['username'],
            token=config['token'],
            warehouse=config.get('warehouse'),
            database=config.get('database'),
            schema=config.get('schema'),
            role=config.get('role')
        )
        
        # Connect and execute
        with client:
            if args.query:
                logger.info(f"Executing query: {args.query}")
                results = client.execute_query(args.query)
            else:
                parameters = parse_parameters(args.parameters)
                logger.info(f"Calling stored procedure: {args.procedure}")
                if parameters:
                    logger.info(f"Parameters: {parameters}")
                results = client.call_stored_procedure(args.procedure, parameters)
            
            # Format output
            if args.output == 'json':
                output = json.dumps(results, indent=2, default=str)
            elif args.output == 'table':
                if results:
                    # Simple table format
                    headers = list(results[0].keys())
                    output = '\t'.join(headers) + '\n'
                    for row in results:
                        output += '\t'.join(str(row.get(header, '')) for header in headers) + '\n'
                else:
                    output = "No results returned.\n"
            elif args.output == 'csv':
                if results:
                    import csv
                    import io
                    output_buffer = io.StringIO()
                    writer = csv.DictWriter(output_buffer, fieldnames=results[0].keys())
                    writer.writeheader()
                    writer.writerows(results)
                    output = output_buffer.getvalue()
                else:
                    output = ""
            
            # Write output
            if args.file:
                with open(args.file, 'w') as f:
                    f.write(output)
                logger.info(f"Output written to {args.file}")
            else:
                print(output)
        
        logger.info("Operation completed successfully")
        
    except ConfigurationError as e:
        logger.error(f"Configuration error: {e}")
        sys.exit(1)
    except AuthenticationError as e:
        logger.error(f"Authentication error: {e}")
        sys.exit(1)
    except SnowflakeConnectionError as e:
        logger.error(f"Connection error: {e}")
        sys.exit(1)
    except StoredProcedureError as e:
        logger.error(f"Stored procedure error: {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
