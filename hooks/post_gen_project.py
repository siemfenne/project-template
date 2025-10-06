#!/usr/bin/env python
import os
import shutil
import stat
import time
import sys

# get the project platform from cookiecutter context
project_platform = '{{ cookiecutter.project_platform }}'
project_development = '{{ cookiecutter.development }}'
project_os = '{{ cookiecutter.operating_system }}'

def safe_rename_folder(old_name, new_name, max_retries=3):
    """
    Safely rename a folder, handling Windows permission issues
    """
    if not os.path.exists(old_name):
        return True
    
    for attempt in range(max_retries):
        try:
            # Remove target folder if it exists
            if os.path.exists(new_name):
                # On Windows, ensure files are not read-only before removal
                def remove_readonly(func, path, _):
                    os.chmod(path, stat.S_IWRITE)
                    func(path)
                
                shutil.rmtree(new_name, onerror=remove_readonly)
                time.sleep(0.1)  # Brief pause for Windows file system
            
            # Rename the folder
            os.rename(old_name, new_name)
            print(f"Renamed {old_name} to {new_name}")
            return True
            
        except PermissionError as e:
            if attempt < max_retries - 1:
                print(f"Permission error on attempt {attempt + 1}, retrying...")
                time.sleep(0.2)
                continue
            else:
                print(f"Failed to rename {old_name} to {new_name}: {e}")
                print("Continuing without rename...")
                return False
        except Exception as e:
            print(f"Unexpected error renaming {old_name} to {new_name}: {e}")
            return False
    
    return False

# fix for macOS/Windows: rename 00snowflake to .snowflake to avoid cookiecutter dotfile issues
safe_rename_folder('00snowflake', '.snowflake')

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
        'create.sh',
        'create.ps1'
    ]
    dirs_to_remove = [
        '.snowflake',
        # '00snowflake',  # fallback in case rename didn't happen
        'streamlit'
    ]
    if project_development == 'Local':
        files_to_remove.append('requirements.txt')
        files_to_remove.append('pyproject.toml')
        files_to_remove.append('environment.yml')
        files_to_remove.append('Pipfile')

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

if project_os == 'Windows':
    # remove setup.sh
    if os.path.exists('setup.sh'):
        os.remove('setup.sh')
        print("Removed setup.sh")
    
    # remove create.ps1
    if os.path.exists('create.sh'):
        os.remove('create.sh')
        print("Removed create.sh")

elif project_os == 'macOS':
    if os.path.exists('setup.ps1'):
        os.remove('setup.ps1')
        print("Removed setup.ps1")
    
    # remove create.ps1
    if os.path.exists('create.ps1'):
        os.remove('create.ps1')
        print("Removed create.ps1")

    shell_scripts = ['setup.sh', 'create.sh']
    for shell_script in shell_scripts:
        if os.path.exists(shell_script):
            # Add execute permission for owner, group, and others
            current_permissions = os.stat(shell_script).st_mode
            os.chmod(shell_script, current_permissions | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
            print(f"Made {shell_script} executable")

print(f"Project template configured for {project_platform}")
print(f"You can continue connecting the project to Azure DevOps and Snowflake/Databricks using the setup.ps1 or setup.sh scripts")