"""
Snowflake REST Calls Library
A Python library for connecting to Snowflake using PAT tokens and executing stored procedures.
"""

from .snowflake_client import SnowflakeClient
from .exceptions import SnowflakeConnectionError, StoredProcedureError

__version__ = "1.0.0"
__all__ = ["SnowflakeClient", "SnowflakeConnectionError", "StoredProcedureError"]
