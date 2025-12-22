import os

################################################################################
################ ENVIRONMENT VARIABLES #########################################
################################################################################
database = os.environ['DEPLOY_DB']
schema = os.environ['DEPLOY_SCHEMA']
repo_name = os.environ['REPO_NAME']
branch = os.environ['BUILD_SOURCEBRANCHNAME']
warehouse = os.environ['WAREHOUSE']
# Container service env vars
compute_pool = os.environ.get('COMPUTE_POOL', '')
min_instances = os.environ.get('MIN_INSTANCES', '1')
max_instances = os.environ.get('MAX_INSTANCES', '1')
image_repo = os.environ.get('IMAGE_REPO_NAME', '')

base_dir = os.path.dirname(__file__)
output_path = os.path.join(base_dir, 'deploy.sql')

deploy_lines = []

################################################################################
################ DATABASE AND SCHEMA SETUP #####################################
################################################################################
use_lines = [
    f"USE DATABASE {database};\n",
    f"CREATE SCHEMA IF NOT EXISTS {schema};\n",
    f"GRANT ALL PRIVILEGES ON SCHEMA {database}.{schema} TO ROLE GR_AI_ENGINEER;\n",
    f"USE SCHEMA {schema};\n\n"
]
deploy_lines.extend(use_lines)

################################################################################
####################### CONTAINERIZED STREAMLIT SERVICES #######################
################################################################################
# Find all streamlit_app.py files with Dockerfiles under the "streamlit" folder
# Only Dockerized apps are deployed via pipeline (native Streamlit apps are 
# managed through Snowflake Workspaces)

streamlit_root = os.path.abspath(os.path.join(base_dir, '..', 'streamlit'))
if os.path.exists(streamlit_root):
    for dirpath, dirnames, filenames in os.walk(streamlit_root):
        for filename in filenames:
            if filename == 'streamlit_app.py':
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
################ WRITE OUTPUT ##################################################
################################################################################
with open(output_path, 'w') as f:
    f.writelines(deploy_lines)

print("\n" + "="*80)
print("Generated SQL statements:")
print("="*80)
with open(output_path, 'r') as f:
    print(f.read())
