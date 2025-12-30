#!/usr/bin/env python
import os
import shutil
import stat

# get the project platform from cookiecutter context
project_platform = '{{ cookiecutter.project_platform }}'
project_development = '{{ cookiecutter.development }}'

# define files to remove based on platform choice
if project_platform == 'Snowflake':
    # remove Databricks-specific files
    files_to_remove = [
        'azure-pipeline-dbx.yml',
        'databricks.yml'
    ]
    dirs_to_remove = [
        'notebooks/requirements'
    ]
elif project_platform == 'Databricks':
    # remove Snowflake-specific files and directories
    files_to_remove = [
        'azure-pipeline-sf.yml',
    ]
    dirs_to_remove = [
        'deploy',
    ]
    if project_development == 'Local':
        files_to_remove.append('notebooks/requirements.txt')
        files_to_remove.append('notebooks/pyproject.toml')
        files_to_remove.append('notebooks/environment.yml')
        files_to_remove.append('notebooks/Pipfile')

# remove unwanted files
for file_name in files_to_remove:
    if os.path.exists(file_name):
        os.remove(file_name)
        print(f"Removed {file_name}")

# remove unwanted directories
for dir_name in dirs_to_remove:
    if os.path.exists(dir_name):
        shutil.rmtree(dir_name)
        print(f"Removed directory {dir_name}")

# Make shell scripts executable (for macOS/Linux users)
shell_scripts = ['setup.sh', 'create.sh']
for shell_script in shell_scripts:
    if os.path.exists(shell_script):
        current_permissions = os.stat(shell_script).st_mode
        os.chmod(shell_script, current_permissions | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        print(f"Made {shell_script} executable")

print(f"Project template configured for {project_platform}")
print(f"You can continue connecting the project to Azure DevOps and Snowflake/Databricks using the setup scripts (setup.ps1 for Windows, setup.sh for macOS/Linux)")