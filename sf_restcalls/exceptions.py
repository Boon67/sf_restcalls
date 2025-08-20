"""
Custom exceptions for the Snowflake REST Calls library.
"""


class SnowflakeConnectionError(Exception):
    """Raised when there's an error connecting to Snowflake."""
    pass


class StoredProcedureError(Exception):
    """Raised when there's an error executing a stored procedure."""
    pass


class AuthenticationError(Exception):
    """Raised when there's an authentication error with the PAT token."""
    pass


class ConfigurationError(Exception):
    """Raised when there's a configuration error."""
    pass
