#!/usr/bin/env python
import os
import shutil
import stat

# get cookiecutter context
project_management = '{{ cookiecutter.project_management }}'
include_dockerfile = '{{ cookiecutter.include_dockerfile }}'

files_to_remove = []
dirs_to_remove = []

# remove files based on project management choice
if project_management == 'Github':
    files_to_remove.append('azure-pipeline.yml')
elif project_management == 'Azure DevOps':
    dirs_to_remove.append('.github')

# remove Docker/GCloud files if Dockerfile is not included
if include_dockerfile == 'No':
    files_to_remove.append('Dockerfile')
    files_to_remove.append('.dockerignore')
    files_to_remove.append('.gcloudignore')

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
shell_scripts = ['setup.sh']
for shell_script in shell_scripts:
    if os.path.exists(shell_script):
        current_permissions = os.stat(shell_script).st_mode
        os.chmod(shell_script, current_permissions | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        print(f"Made {shell_script} executable")

print(f"Project template configured with {project_management} for project management")
print(f"Run ./setup.sh to connect the project to {project_management}")