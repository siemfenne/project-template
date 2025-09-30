import os

database = os.environ['DEPLOY_DB']
schema = os.environ['DEPLOY_SCHEMA']
repo_name = os.environ['REPO_NAME']
branch = os.environ['BUILD_SOURCEBRANCHNAME']
warehouse = os.environ['WAREHOUSE']
utility_db = os.environ['UTILITY_DB']
git_schema = os.environ['GIT_SCHEMA']

base_dir = os.path.dirname(__file__)
output_path = os.path.join(base_dir, 'deploy.sql')

deploy_lines = []
use_lines = [
    f"USE DATABASE {database};\n",
    f"CREATE SCHEMA IF NOT EXISTS {schema};\n",
    f"GRANT ALL PRIVILEGES ON SCHEMA {database}.{schema} TO ROLE GR_AI_ENGINEER;\n",
    f"USE SCHEMA {schema};\n\n"
]
deploy_lines.extend(use_lines)

# --- NOTEBOOKS ---
for root, dirs, files in os.walk('..'):
    for file in files:
        if file.endswith('.ipynb'):
            file_without_ext = os.path.splitext(file)[0]
            relative_path = os.path.relpath(root, '.')
            full_repo_path = f'@"{utility_db}"."{git_schema}"."{repo_name}"/branches/{branch}/{relative_path}/'
            deploy_lines.append(f"""
CREATE OR REPLACE NOTEBOOK IDENTIFIER('"{database}"."{schema}"."{file_without_ext}"')
FROM {full_repo_path}
WAREHOUSE = '{warehouse}'
QUERY_WAREHOUSE = '{warehouse}'
RUNTIME_NAME = 'SYSTEM$WAREHOUSE_RUNTIME'
MAIN_FILE = '{file}'
;
""")
            deploy_lines.append(f"""
ALTER NOTEBOOK "{database}"."{schema}"."{file_without_ext}" ADD LIVE VERSION FROM LAST
;        
""")

# --- STREAMLIT ---
# find all streamlit_app.py files under the "streamlit" folder (any depth)
streamlit_root = os.path.abspath(os.path.join(base_dir, '..', 'streamlit'))
if os.path.exists(streamlit_root):
    for dirpath, dirnames, filenames in os.walk(streamlit_root):
        for filename in filenames:
            if filename == 'streamlit_app.py':
                app_path = os.path.join(dirpath, filename)
                # check if file is not empty
                if os.path.getsize(app_path) > 0:
                    relative_path = os.path.relpath(dirpath, '.')
                    full_repo_path = f'@"{utility_db}"."{git_schema}"."{repo_name}"/branches/{branch}/{relative_path}/'
                    # generate a unique name for each app (e.g. include subfolder name if present)
                    # use the path after "streamlit/" as the app name (or just repo and branch if top-level)
                    rel_to_streamlit = os.path.relpath(dirpath, streamlit_root)
                    if rel_to_streamlit == '.':
                        streamlit_name = f'{repo_name}_{branch}'
                    else:
                        # remove separators for valid object name
                        subfolder_part = rel_to_streamlit.replace(os.sep, '_')
                        streamlit_name = f'{repo_name}_{branch}_{subfolder_part}'
                    deploy_lines.append(f"""
CREATE OR REPLACE STREAMLIT IDENTIFIER('"{database}"."{schema}"."{streamlit_name}"')
FROM {full_repo_path}
MAIN_FILE = 'streamlit_app.py'
QUERY_WAREHOUSE = '{warehouse}'
;
""")

################################################################################
################ DEFINE LIST OF NOTEBOOKS TO EXECUTE  ##########################
################ ON DEPLOY, INCLUDING NOTEBOOK PARAMS ##########################
################################################################################
# execute_list = [
#     # (notebook_name, notebook_params)
#     ("DEVOPS_01_00_DATABASE_INIT", f"DATABASE={database} SCHEMA={schema}"),
#     ("DEVOPS_00_01_SCHEDULER", f"DATABASE={database} SCHEMA={schema} WAREHOUSE={warehouse}")
# ]

# # ################################################################################
# # ################ EXECUTE NOTEBOOKS COMMANDS ####################################
# # ################################################################################
# for notebook_name, notebook_params in execute_list:
#     deploy_lines.append(f"""
# EXECUTE NOTEBOOK IDENTIFIER('"{database}"."{schema}"."{notebook_name}"')('{notebook_params}');
# """)

# Write the files
with open(output_path, 'w') as f:
    f.writelines(deploy_lines)

print("Generated SQL statements:")
with open(output_path, 'r') as f:
    print(f.read())
