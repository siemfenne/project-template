#!/bin/bash
set -euo pipefail

case "$OSTYPE" in
  msys*|cygwin*)
    # Git Bash on Windows
    AZ="/c/Users/fennes2/azure-cli-2.75.0-x64/bin/az.cmd"
    DBX_PATH_PREFIX="//Workspace"   # prevent MSYS path conversion
    ;;
  darwin*)
    # macOS (brew install azure-cli)
    AZ="az"
    DBX_PATH_PREFIX="/Workspace"
    ;;
  linux*|gnu*|*wsl*)
    # WSL (install az in the distro: apt/microsoft repo)
    AZ="az"
    DBX_PATH_PREFIX="/Workspace"
    ;;
  *)
    echo "Unsupported OSTYPE: $OSTYPE" >&2
    exit 1
    ;;
esac

# --- Config ---
organization="https://dev.azure.com/MedtronicBI"
project="DigIC GR AI"

# --- Azure DevOps ---
"$AZ" devops configure --defaults organization="$organization" project="$project"

read -p "Enter new repository name: " repo_name
"$AZ" repos create --name "$repo_name"

remote_project=$(echo "$project" | sed 's/ /%20/g')
remote_url="$organization/$remote_project/_git/$repo_name"

git init
git add .
git commit -m "Initial commit: project template" || true
git branch -M main
git remote add origin "$remote_url" 2>/dev/null || git remote set-url origin "$remote_url"
git push -u origin main

if ! git branch --list | grep -q "^  stage$"; then
  git checkout -b stage
  git push -u origin stage
fi
git checkout main
if ! git branch --list | grep -q "^  dev$"; then
  git checkout -b dev
  git push -u origin dev
fi
git checkout main

echo "Setup complete! Repo '$repo_name' created in Azure DevOps, branches ready."

read -p "Do you want to link this repo in Snowflake? (y/n): " setupSnowflake
read -p "Do you want to link this repo in Databricks? (y/n): " setupDatabricks

if [[ "$setupSnowflake" =~ ^[Yy]$ ]]; then
  read -s -p "Enter private key passphrase: " passphrase; echo
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

if [[ "$setupDatabricks" =~ ^[Yy]$ ]]; then
  read -p "Enter your Medtronic username (e.g. fennes2 for Siem Fenne): " user_name
  dbx_email="$user_name@medtronic.com"
  dbx_path="$DBX_PATH_PREFIX/Users/$dbx_email/$repo_name"

  declare -A dbx_envs=([PROD]=prod [STAGE]=stage [DEV]=dev)
  for env in PROD STAGE DEV; do
    profile="${dbx_envs[$env]}"
    echo "Linking repo in Databricks $env environment with CLI profile '$profile'..."
    if [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
      MSYS_NO_PATHCONV=1 databricks --profile "$profile" repos create "$remote_url" azureDevOpsServices --path "$dbx_path" \
        && echo "Successfully linked to Databricks $env at $dbx_path" \
        || echo "Could not create repo in Databricks $env."
    else
      databricks --profile "$profile" repos create "$remote_url" azureDevOpsServices --path "$dbx_path" \
        && echo "Successfully linked to Databricks $env at $dbx_path" \
        || echo "Could not create repo in Databricks $env."
    fi
  done
  echo "Databricks integration complete."
fi

echo "All done! Project ready, and integrations completed if chosen."