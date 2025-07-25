from os import environ
import sys
import platform
from pathlib import Path  

class MdtEnvironment:
    """
    Helper class that detects which environment code runs on.
    Contains static methods only.
    """

    @staticmethod
    def detect_environment():
        """
        Detects which environment code runs on and returns it as a string.

        Returns:
        str: The environment name. Can be one of the following values: 
             - "snowflake_container_services": When code is run on a Snowflake Container Services instance.
             - "snowflake_container_runtime": When code is run on a Snowflake Container Runtime instance.
             - "snowflake_warehouse_streamlit" : When code is run in Streamlit on Snowflake (always warehouse)
             - "snowflake_warehouse" : When code is run on a Snowflake Warehouse instance (and not Streamlit)
             - "databricks" : When code runs on Databricks.
             - "local": When code is run on another environment than the above ones.
        """
        # Snowflake Container
        if MdtEnvironment.on_snowflake_container():
            # Snowflake Container Runtime detection.
            if environ.get('OBJECT_DOMAIN') == 'NOTEBOOK':
                return "snowflake_container_runtime"
            else:        
                # If not container runtime, then it must be container services
                return "snowflake_container_services"
            
        # Snowflake warhouse
        if MdtEnvironment.on_snowflake_warehouse():
            # Determine if code is run on in Streamlit app on Snowflake
            if "/tmp/appRoot/streamlit_app.py" in sys.path:
                return "snowflake_warehouse_streamlit"
            
            # TO DO: determine if UDF is run in Notebook, Worksheet, or SQL Python UDF
            return "snowflake_warehouse"
        
        # TO DO: implement detect Databricks, see function.
        if MdtEnvironment.on_databricks():
            return "databricks"

        # Everything else
        return "local"
    
    @staticmethod
    def on_snowflake_container():
        """Determines if code is run on a Snowflake container.

        Returns:
           bool: True if code is run on a Snowflake container, False otherwise.
        """        
        return any([
            # Method 1: check session token file exists
            # See https://docs.snowflake.com/en/developer-guide/snowpark-container-services/additional-considerations-services-jobs
            Path("/snowflake/session/token").exists(),
            # Method 2: check environment variables
            'SPCS_CONTAINER_ID' in environ,
            'SPCS_POD_NAME' in environ,
            'SPCS_POD_NAMESPACE' in environ,
        ]) 

    @staticmethod
    def on_snowflake_warehouse():
        """Determines if code is run on a Snowflake warehouse instance.

        Returns:
           bool: True if code is run on a Snowflake warhouse instance, False otherwise.
        """
        return any([
            # Method one: check environment variables
            environ.get('USER')=='udf',
            environ.get('LOGNAME')=='udf',
            environ.get('HOME')=='udf',
            # Method two: check platform is PYTHON-UDF
            platform.node() == 'PYTHON-UDF',
        ])

    @staticmethod
    def on_databricks():
        """Determines if code is run on Databricks.

        Returns:
           bool: True if code is run on Databricks, False otherwise.
        """
        # TO DO: implement this method
        pass
