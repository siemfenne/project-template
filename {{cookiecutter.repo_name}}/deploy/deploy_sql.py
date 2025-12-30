import os

################################################################################
################ ENVIRONMENT VARIABLES #########################################
################################################################################
database = os.environ['DEPLOY_DB']
schema = os.environ['DEPLOY_SCHEMA']
repo_name = os.environ['REPO_NAME']
branch = os.environ['BUILD_SOURCEBRANCHNAME']
warehouse = os.environ['WAREHOUSE']
workspace_owner = os.environ.get('WORKSPACE_OWNER', 'USER$')  # Snowflake username who owns the workspace
# Container service env vars
compute_pool = os.environ.get('COMPUTE_POOL', '')
min_instances = os.environ.get('MIN_INSTANCES', '1')
max_instances = os.environ.get('MAX_INSTANCES', '1')
image_repo = os.environ.get('IMAGE_REPO_NAME', '')

base_dir = os.path.dirname(__file__)
output_path = os.path.join(base_dir, 'deploy.sql')

deploy_lines = []

################################################################################
################ DATABASE, SCHEMA, NOTEBOOK PROJECT SETUP ######################
################################################################################
workspace_url = f'snow://workspace/USER${workspace_owner}.PUBLIC.{repo_name}/versions/head/'

use_lines = [
    f"USE DATABASE {database};\n",
    f"CREATE SCHEMA IF NOT EXISTS {schema};\n",
    f"GRANT ALL PRIVILEGES ON SCHEMA {database}.{schema} TO ROLE GR_AI_ENGINEER;\n",
    f"USE SCHEMA {schema};\n\n",
    f"CREATE OR REPLACE NOTEBOOK PROJECT {database}.{schema}.{repo_name}\n",
    f"  FROM '{workspace_url}';\n"
]
deploy_lines.extend(use_lines)

################################################################################
####################### CONTAINERIZED STREAMLIT SERVICES #######################
################################################################################
# Find all streamlit_app.py files with Dockerfiles under the "streamlit" folder
# Only Dockerized apps are deployed via pipeline (native Streamlit apps are 
# managed through Snowflake Workspaces)

streamlit_root = os.path.abspath(os.path.join(base_dir, '..', 'apps'))
if os.path.exists(streamlit_root):
    for dirpath, dirnames, filenames in os.walk(streamlit_root):
        for filename in filenames:
            if filename == 'main.py':
                app_path = os.path.join(dirpath, filename)
                dockerfile_path = os.path.join(dirpath, 'Dockerfile')
                
                # Generate name based on folder location (all uppercase)
                rel_to_streamlit = os.path.relpath(dirpath, streamlit_root)
                if rel_to_streamlit == '.':
                    app_name = f'{repo_name}_{branch}'.upper()
                else:
                    subfolder_part = rel_to_streamlit.replace(os.sep, '_')
                    app_name = f'{repo_name}_{branch}_{subfolder_part}'.upper()
                
                # Only deploy if Dockerfile exists (containerized Streamlit apps)
                if os.path.exists(dockerfile_path) and compute_pool and image_repo:
                    service_name = f'{app_name}_SERVICE'
                    # Image name includes subfolder to support multiple apps
                    image_name = f'{app_name.lower()}_image'
                    image_path = f'/{database}/IMAGE_REPO/{image_repo}/{image_name}:latest'
                    deploy_lines.append(f"""DROP SERVICE IF EXISTS "{database}"."{schema}"."{service_name}";""")
                    deploy_lines.append(f"""
-- Container Service: {service_name}
CREATE SERVICE "{database}"."{schema}"."{service_name}"
  IN COMPUTE POOL {compute_pool}
  FROM SPECIFICATION $$
spec:
  containers:
    - name: app
      image: {image_path}
      env:
        SNOWFLAKE_WAREHOUSE: {warehouse}
  endpoints:
    - name: app
      port: 8501
      public: true
serviceRoles:
  - name: GR_AI_ENGINEER
    endpoints:
      - app
$$
  MIN_INSTANCES={min_instances}
  MAX_INSTANCES={max_instances}
  QUERY_WAREHOUSE={warehouse};
""")

################################################################################
################ EXECUTE NOTEBOOKS ON DEPLOY ###################################
################ UNCOMMENT AND CONFIGURE AS NEEDED #############################
################################################################################
# List of notebooks to execute on deploy
# Format: (notebook_file, compute_pool, runtime, external_access_integrations, arguments)
# - notebook_file: path relative to workspace root (e.g., 'notebooks/NOTEBOOK1.ipynb')
# - compute_pool: compute pool name for container runtime execution
# - runtime: runtime version (e.g., 'V2.2-CPU-PY3.11')
# - external_access_integrations: list of EAI names or empty list
# - arguments: (optional) string of CLI-style arguments passed to the notebook
#              Use f-strings for dynamic values: database, schema, repo_name, branch, warehouse
#              e.g., f'--database="{database}" --schema="{schema}" --custom="value"'
#              In the notebook, parse with argparse: args, _ = parser.parse_known_args(sys.argv[1:])

execute_list = [
    ("notebooks/NOTEBOOK1.ipynb", f"{compute_pool}", "V2.2-CPU-PY3.11", ["EXT_XS_INT_PYPI"], f'--database="{database}" --schema="{schema}"'),
    ("notebooks/NOTEBOOK2.ipynb", f"{compute_pool}", "V2.2-CPU-PY3.11", ["EXT_XS_INT_PYPI"], f'--database="{database}" --schema="{schema}"'),
]

for notebook_file, cp, runtime, eai_list, *optional in execute_list:
    # Handle optional arguments parameter (5th element)
    arguments = optional[0] if optional else ""
    
    # Build optional clauses
    eai_values = ', '.join(f"'{e}'" for e in eai_list)
    eai_str = f"  EXTERNAL_ACCESS_INTEGRATIONS = ({eai_values})\n" if eai_list else ""
    args_str = f"  ARGUMENTS = '{arguments}'\n" if arguments else ""
    
    deploy_lines.append(f"""
EXECUTE NOTEBOOK PROJECT {database}.{schema}.{repo_name}
  MAIN_FILE = '{notebook_file}'
  COMPUTE_POOL = '{cp}'
  RUNTIME = '{runtime}'
  QUERY_WAREHOUSE = '{warehouse}'
{eai_str}{args_str};
""")

################################################################################
################ WRITE OUTPUT ##################################################
################################################################################
with open(output_path, 'w') as f:
    f.writelines(deploy_lines)

print("\n" + "="*80)
print("Generated SQL statements:")
print("="*80)
with open(output_path, 'r') as f:
    print(f.read())
