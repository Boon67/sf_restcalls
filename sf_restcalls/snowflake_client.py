"""
Snowflake client for connecting with PAT tokens and executing stored procedures.
"""

import snowflake.connector
from typing import Dict, Any, List, Optional
import logging
from .exceptions import (
    SnowflakeConnectionError, 
    StoredProcedureError, 
    AuthenticationError,
    ConfigurationError
)


class SnowflakeClient:
    """
    A client for connecting to Snowflake using PAT tokens and executing stored procedures.
    """
    
    def __init__(self, 
                 account: str,
                 username: str, 
                 token: str,
                 warehouse: Optional[str] = None,
                 database: Optional[str] = None,
                 schema: Optional[str] = None,
                 role: Optional[str] = None):
        """
        Initialize the Snowflake client.
        
        Args:
            account: Snowflake account identifier
            username: Snowflake username
            token: Personal Access Token (PAT)
            warehouse: Snowflake warehouse (optional)
            database: Snowflake database (optional)
            schema: Snowflake schema (optional)
            role: Snowflake role (optional)
        """
        self.account = account
        self.username = username
        self.token = token
        self.warehouse = warehouse
        self.database = database
        self.schema = schema
        self.role = role
        self.connection = None
        
        # Set up logging
        self.logger = logging.getLogger(__name__)
        
    def connect(self) -> None:
        """
        Establish connection to Snowflake using PAT token.
        
        Raises:
            SnowflakeConnectionError: If connection fails
            AuthenticationError: If authentication fails
        """
        try:
            connection_params = {
                'account': self.account,
                'user': self.username,
                'token': self.token,
                'authenticator': 'oauth',
            }
            
            # Add optional parameters if provided
            if self.warehouse:
                connection_params['warehouse'] = self.warehouse
            if self.database:
                connection_params['database'] = self.database
            if self.schema:
                connection_params['schema'] = self.schema
            if self.role:
                connection_params['role'] = self.role
                
            self.logger.info(f"Connecting to Snowflake account: {self.account}")
            self.connection = snowflake.connector.connect(**connection_params)
            self.logger.info("Successfully connected to Snowflake")
            
        except snowflake.connector.errors.DatabaseError as e:
            if "authentication" in str(e).lower():
                raise AuthenticationError(f"Authentication failed: {e}")
            else:
                raise SnowflakeConnectionError(f"Failed to connect to Snowflake: {e}")
        except Exception as e:
            raise SnowflakeConnectionError(f"Unexpected error connecting to Snowflake: {e}")
    
    def disconnect(self) -> None:
        """Close the Snowflake connection."""
        if self.connection:
            self.connection.close()
            self.connection = None
            self.logger.info("Disconnected from Snowflake")
    
    def is_connected(self) -> bool:
        """Check if connected to Snowflake."""
        return self.connection is not None and not self.connection.is_closed()
    
    def call_stored_procedure(self, 
                            procedure_name: str, 
                            parameters: Optional[List[Any]] = None) -> List[Dict[str, Any]]:
        """
        Call a stored procedure and return the results.
        
        Args:
            procedure_name: Name of the stored procedure to call
            parameters: List of parameters to pass to the stored procedure
            
        Returns:
            List of dictionaries containing the results
            
        Raises:
            SnowflakeConnectionError: If not connected
            StoredProcedureError: If procedure execution fails
        """
        if not self.is_connected():
            raise SnowflakeConnectionError("Not connected to Snowflake. Call connect() first.")
        
        try:
            cursor = self.connection.cursor()
            
            # Build the CALL statement
            if parameters:
                # Create parameter placeholders
                placeholders = ', '.join(['%s'] * len(parameters))
                call_statement = f"CALL {procedure_name}({placeholders})"
                self.logger.info(f"Executing: {call_statement} with parameters: {parameters}")
                cursor.execute(call_statement, parameters)
            else:
                call_statement = f"CALL {procedure_name}()"
                self.logger.info(f"Executing: {call_statement}")
                cursor.execute(call_statement)
            
            # Fetch results
            results = []
            if cursor.description:
                columns = [desc[0] for desc in cursor.description]
                for row in cursor.fetchall():
                    row_dict = dict(zip(columns, row))
                    results.append(row_dict)
            
            cursor.close()
            self.logger.info(f"Successfully executed stored procedure {procedure_name}, returned {len(results)} rows")
            return results
            
        except snowflake.connector.errors.ProgrammingError as e:
            raise StoredProcedureError(f"Error executing stored procedure {procedure_name}: {e}")
        except Exception as e:
            raise StoredProcedureError(f"Unexpected error executing stored procedure {procedure_name}: {e}")
    
    def call_sp_example(self, parameters: Optional[List[Any]] = None) -> List[Dict[str, Any]]:
        """
        Convenience method to call the sp_example stored procedure.
        
        Args:
            parameters: List of parameters to pass to sp_example
            
        Returns:
            List of dictionaries containing the results
        """
        return self.call_stored_procedure("sp_example", parameters)
    
    def execute_query(self, query: str) -> List[Dict[str, Any]]:
        """
        Execute a SQL query and return results.
        
        Args:
            query: SQL query to execute
            
        Returns:
            List of dictionaries containing the results
            
        Raises:
            SnowflakeConnectionError: If not connected
            StoredProcedureError: If query execution fails
        """
        if not self.is_connected():
            raise SnowflakeConnectionError("Not connected to Snowflake. Call connect() first.")
        
        try:
            cursor = self.connection.cursor()
            self.logger.info(f"Executing query: {query}")
            cursor.execute(query)
            
            results = []
            if cursor.description:
                columns = [desc[0] for desc in cursor.description]
                for row in cursor.fetchall():
                    row_dict = dict(zip(columns, row))
                    results.append(row_dict)
            
            cursor.close()
            self.logger.info(f"Query executed successfully, returned {len(results)} rows")
            return results
            
        except snowflake.connector.errors.ProgrammingError as e:
            raise StoredProcedureError(f"Error executing query: {e}")
        except Exception as e:
            raise StoredProcedureError(f"Unexpected error executing query: {e}")
    
    def __enter__(self):
        """Context manager entry."""
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.disconnect()
