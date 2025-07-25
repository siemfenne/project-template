# Standard libs
from os import environ
from pathlib import Path
import warnings

# Non-standard libs
from snowflake.snowpark import Session
from snowflake.snowpark.context import get_active_session

# Medtronic libs
from shared.mdt_environment import MdtEnvironment

# Optional libs (only imports when available)
# Set environment variables based on .env file.
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    warnings.warn("Python library 'dotenv' not found, environment variables won't be loaded")

class MdtSnowPark:
    """Helper class for interacting with Snowpark.
    It provides a method to get a new session.
    In case a connection is needed, it will be created automatically.
    It makes use of MdtEnvironment, to determine which connection method should be used.
    """

    @staticmethod
    def get_session(connection_parameters={}, load_from_env=True):
        """Returns a SnowPark session.
        On warehouses, the active session is returned. 
        On other environments, a new connection will be created.
        Connection parameters can be provided using the connection_parameters dict,
        or a .env file (see function get_snowflake_environment_variables() for more details).
        Parameters:
            connection_parameters (dict): A dictionary containing additional parameters.
            These will overwrite any parameters that have been provided via environment variables.
            load_from_env (bool): Whether to load connection parameters from environment variables. Default is True.
            For supported parameters, see https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-api#label-snowflake-connector-methods
        """
        # If code is run on a warehouse, just return the active session
        if MdtEnvironment.on_snowflake_warehouse():
            return get_active_session()
        
        # In all other cases, a new connection has to be created        
        # Load connection parameters from environment variables if load_from_env is True
        # Make sure that connection_parameters from the function call remain leading.
        if load_from_env:
            connection_parameters.update({key: value 
                                          for key, value in MdtSnowPark.get_snowflake_environment_variables().items()
                                          if not key in connection_parameters.keys()})
        
        # Define an error checking function to check if manadatory parameters have been set.
        def raise_on_missing_parameters(connection_parameters, mandatory_parameters):
            missing_parameters = [_ for _ in mandatory_parameters if not _ in connection_parameters.keys()]
            if missing_parameters:
                raise NameError(f'The following connection parameters are missing that are mandatory when connecting from {MdtEnvironment.detect_environment()}: {", ".join(missing_parameters)}')
        
        # Specifics for Snowflake Container Services / Runtime
        # Connect using user specific token filecreated by SPCS
        if MdtEnvironment.on_snowflake_container():
            # Preset connection method to oauth
            connection_parameters['protocol'] = "https"
            connection_parameters['authenticator'] = "oauth"
            connection_parameters['token'] = open('/snowflake/session/token', 'r').read()
            raise_on_missing_parameters(connection_parameters, mandatory_parameters=[
                'host', #Set by SPCS
                'port', #Set by SPCS
                'account', #Set by SPCS
                'warehouse', #Set by SPCS
                'database', #Set by SPCS
                'schema', #Set by SPCS
            ])
        else:
            # If not in Snowpark warehouse or Snowpark container,
            # Cnnect using certificate file
            raise_on_missing_parameters(connection_parameters, mandatory_parameters=[
                'account',
                'user',
                'private_key_file',
                'private_key_file_pwd',
                'warehouse',
                'database',
                'schema',
                #'authenticator', #snowflake cli requires that this is set to SNOWFLAKE_JWT, python doesn't
            ])
        
        # Update key file path when needed
        if 'private_key_file' in connection_parameters:
            # Check if file exists, otherwise traverse back from the current working directory.
            # If it can't be found there, default to its original value
            original_path = Path(connection_parameters['private_key_file'])
            connection_parameters['private_key_file'] = original_path if original_path.exists() else next((updated_path for _ in [Path.cwd()] + list(Path.cwd().parents) if (updated_path := _ / original_path.name).exists()), original_path)
        
        # Build the connection and return the session
        return Session.builder.configs(connection_parameters).create()


    @staticmethod
    def get_snowflake_environment_variables():
        """Loads snowflake connection paramaters from environment variables.
        Environment variables follow the following naming convention: 'SNOWFLAKE_PARAMETER_NAME'.
        So connection parameter 'user' has te specified as environment variable 'SNOWFLAKE_USER'.
        For supported parameters, see https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-api#label-snowflake-connector-methods
        Returns:
            dict: A dictionary containing the connection parameters (key) and values.
        """
        supported_params = {_ : f'SNOWFLAKE_{_.upper()}' for _ in [
            'account',
            'user',
            'password',
            'application',
            'region',
            'host',
            'port',
            'database',
            'schema',
            'role',
            'warehouse',
            'passcode_in_password',
            'passcode',
            'private_key',
            'private_key_file',
            'private_key_file_pwd',
            'autocommit',
            'client_prefetch_threads',
            'client_session_keep_alive',
            'login_timeout',
            'network_timeout',
            'ocsp_response_cache_filename',
            'authenticator',
            'validate_default_parameters',
            'paramstyle',
            'timezone',
            'arrow_number_to_decimal',
            'socket_timeout',
            'backoff_policy',
            'enable_connection_diag',
            'connection_diag_log_path',
            'connection_diag_allowlist_path',
            'iobound_tpe_limit',
            'unsafe_file_write'
        ]}
        # Return a dictionary with parameters and matching environment variable values
        return {_: environ[env_param] for _, env_param in supported_params.items() if env_param in environ}

        
        