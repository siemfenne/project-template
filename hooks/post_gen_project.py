#!/usr/bin/env python
import os
import shutil

# get the project platform from cookiecutter context
project_platform = '{{ cookiecutter.project_platform }}'

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

print(f"Project template configured for {project_platform}")
