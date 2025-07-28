#!/bin/bash

set -e

# Set your Azure DevOps org and project
organization="https://dev.azure.com/MedtronicBI"
project="DigIC GR AI"

# Configure Azure DevOps CLI
az devops configure --defaults organization="$organization" project="$project"

# Prompt for new repo name
read -p "Enter new repository name: " repo_name

# Create the new repository in Azure DevOps
az repos create --name "$repo_name"

# URL encode the project name (replace spaces with %20)
remote_project=$(echo "$project" | sed 's/ /%20/g')

# Build the correct remote URL
remote_url="$organization/$remote_project/_git/$repo_name"

# Initialize local git and first commit
git init
git add .
git commit -m "Initial commit: project template"
git branch -M main

# Add remote and push
git remote add origin "$remote_url"
git push -u origin main

# Create and push stage branch if not exists
if ! git branch --list | grep -q "stage"; then
    git checkout -b stage
    git push -u origin stage
fi
git checkout main

# Create and push dev branch if not exists
if ! git branch --list | grep -q "dev"; then
    git checkout -b dev
    git push -u origin dev
fi
git checkout main

echo "Setup complete! Repo '$repo_name' created in Azure DevOps, branches ready."

read -p "Do you want to link this repo in Snowflake? (y/n): " setupSnowflake
read -p "Do you want to link this repo in Databricks? (y/n): " setupDatabricks

if [[ "$setupSnowflake" == "y" || "$setupSnowflake" == "Y" ]]; then
    # Prompt for Snowflake passphrase (set env var for this session)
    read -s -p "Enter private key passphrase: " passphrase
    echo
    export PRIVATE_KEY_PASSPHRASE="$passphrase"

    sf_cmd="
CREATE GIT REPOSITORY IF NOT EXISTS $repo_name
  ORIGIN = '$remote_url'
  API_INTEGRATION = API_GR_GIT_AZURE_DEVOPS
  GIT_CREDENTIALS = EMEA_UTILITY_DB.SECRETS.SECRET_GR_GIT_AZURE_DEVOPS;
"

    echo "Creating Git repository object in Snowflake..."
    echo "$sf_cmd" | snow sql -c service_principal

    databases=("PROD_GR_AI_DB" "STAGE_GR_AI_DB" "DEV_GR_AI_DB")
    role="GR_AI_ENGINEER"

    echo "Creating schemas and assigning grants in each environment database..."
    for db in "${databases[@]}"; do
        sql="
USE DATABASE $db;
CREATE SCHEMA IF NOT EXISTS $repo_name;
GRANT ALL PRIVILEGES ON SCHEMA $repo_name TO ROLE $role;
"
        echo "Initializing schema and grants in $db..."
        echo "$sql" | snow sql -c service_principal
    done

    unset PRIVATE_KEY_PASSPHRASE
fi

if [[ "$setupDatabricks" == "y" || "$setupDatabricks" == "Y" ]]; then
    read -p "Databricks workspace path for the repo (e.g. /Repos/your.email@domain.com/$repo_name): " dbx_path
    databricks repos create --url "$remote_url" --provider azureDevOpsServices --path "$dbx_path"
fi

echo "All done! Project ready, and integrations completed if chosen."
