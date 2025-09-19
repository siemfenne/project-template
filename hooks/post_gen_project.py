#!/usr/bin/env python
import os
import shutil
import stat

# get the project platform from cookiecutter context
project_platform = '{{ cookiecutter.project_platform }}'

# fix for macOS: rename 00snowflake to .snowflake to avoid cookiecutter dotfile issues
if os.path.exists('00snowflake'):
    if os.path.exists('.snowflake'):
        shutil.rmtree('.snowflake')
    os.rename('00snowflake', '.snowflake')
    # print("Renamed 00snowflake to .snowflake (macOS compatibility fix)")

# define files to remove based on platform choice
if project_platform == 'Snowflake':
    # remove Databricks-specific files
    files_to_remove = [
        'azure-pipeline-dbx.yml',
        'databricks.yml'
    ]
    dirs_to_remove = []
elif project_platform == 'Databricks':
    # remove Snowflake-specific files and directories
    files_to_remove = [
        'azure-pipeline-sf.yml'
    ]
    dirs_to_remove = [
        '.snowflake',
        # '00snowflake',  # fallback in case rename didn't happen
        'streamlit'
    ]

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

# Set executable permissions on shell scripts
shell_scripts = ['setup.sh', 'setup_eh.sh']
for script in shell_scripts:
    if os.path.exists(script):
        # Add execute permission for owner, group, and others
        current_permissions = os.stat(script).st_mode
        os.chmod(script, current_permissions | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        print(f"Made {script} executable")

print(f"Project template configured for {project_platform}")
print(f"You can continue connecting the project to Azure DevOps and Snowflake/Databricks using the setup.ps1 or setup.sh scripts")