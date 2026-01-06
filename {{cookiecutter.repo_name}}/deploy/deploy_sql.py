import os

################################################################################
################ ENVIRONMENT VARIABLES #########################################
################################################################################
database = os.environ['DEPLOY_DB']
schema = os.environ['DEPLOY_SCHEMA']
repo_name = os.environ['REPO_NAME']
branch = os.environ['BUILD_SOURCEBRANCHNAME']
warehouse = os.environ['WAREHOUSE']
utility_db = os.environ['UTILITY_DB']
git_schema = os.environ['GIT_SCHEMA']
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

use_lines = [
    f"USE DATABASE {database};\n",
    f"CREATE SCHEMA IF NOT EXISTS {schema};\n",
    f"GRANT ALL PRIVILEGES ON SCHEMA {database}.{schema} TO ROLE GR_AI_ENGINEER;\n",
    f"USE SCHEMA {schema};\n\n"
]
deploy_lines.extend(use_lines)

################################################################################
################ NOTEBOOKS #####################################################
################################################################################
for root, dirs, files in os.walk('..'):
    for file in files:
        if file.endswith('.ipynb'):
            file_without_ext = os.path.splitext(file)[0]
            relative_path = os.path.relpath(root, '.')
            full_repo_path = f'@"{utility_db}"."{git_schema}"."{repo_name}"/branches/{branch}/{relative_path}/'
            deploy_lines.append(f"""
CREATE OR REPLACE NOTEBOOK IDENTIFIER('"{database}"."{schema}"."{file_without_ext}"')
FROM {full_repo_path}
COMPUTE_POOL = '{compute_pool}'
QUERY_WAREHOUSE = '{warehouse}'
RUNTIME_NAME = 'SYSTEM$BASIC_RUNTIME'
MAIN_FILE = '{file}'
;
""")
            deploy_lines.append(f"""
ALTER NOTEBOOK "{database}"."{schema}"."{file_without_ext}" ADD LIVE VERSION FROM LAST
;        
""")
            deploy_lines.append(f"""
ALTER NOTEBOOK "{database}"."{schema}"."{file_without_ext}" SET EXTERNAL_ACCESS_INTEGRATIONS = ('EXT_XS_INT_PYPI')
;        
""")

################################################################################
####################### (STREAMLIT) WEB APPS  ##################################
################################################################################
# Find all streamlit_app.py files under the "streamlit" folder (any depth)
# - If Dockerfile exists in folder → deploy as Container Service
# - If no Dockerfile → deploy as native Snowflake Streamlit app

streamlit_root = os.path.abspath(os.path.join(base_dir, '..', 'apps'))
if os.path.exists(streamlit_root):
    for dirpath, dirnames, filenames in os.walk(streamlit_root):
        for filename in filenames:
            if filename == 'main.py' or filename == 'streamlit_app.py':
                app_path = os.path.join(dirpath, filename)
                dockerfile_path = os.path.join(dirpath, 'Dockerfile')
                relative_path = os.path.relpath(dirpath, '.')
                full_repo_path = f'@"{utility_db}"."{git_schema}"."{repo_name}"/branches/{branch}/{relative_path}/'
                
                # Generate name based on folder location (all uppercase)
                rel_to_streamlit = os.path.relpath(dirpath, streamlit_root)
                if rel_to_streamlit == '.':
                    app_name = f'{repo_name}_{branch}'.upper()
                else:
                    subfolder_part = rel_to_streamlit.replace(os.sep, '_')
                    app_name = f'{repo_name}_{branch}_{subfolder_part}'.upper()
                
                # If Dockerfile exists → deploy as Container Service
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
                
                # No Dockerfile → deploy as native Streamlit app
                elif os.path.getsize(app_path) > 0:
                    deploy_lines.append(f"""
CREATE OR REPLACE STREAMLIT IDENTIFIER('"{database}"."{schema}"."{app_name}"')
FROM {full_repo_path}
MAIN_FILE = '{filename}'
QUERY_WAREHOUSE = '{warehouse}'
;
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
