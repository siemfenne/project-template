#!/bin/bash

# Enhanced setup script with comprehensive error handling
# Exit on any error, but we'll handle errors gracefully where needed
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "An error occurred on line $line_number. Exit code: $exit_code"
    log_error "Rolling back any partial changes..."
    cleanup_on_error
    exit $exit_code
}

# Cleanup function for error scenarios
cleanup_on_error() {
    log_warning "Performing cleanup..."
    # Remove git remote if it was added
    if git remote get-url origin &>/dev/null; then
        git remote remove origin 2>/dev/null || true
    fi
    # Reset to initial state if needed
    if [[ -d .git ]]; then
        log_warning "Git repository was initialized but setup failed. Consider running 'rm -rf .git' to reset."
    fi
}

# Set up error trapping
trap 'handle_error ${LINENO}' ERR

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate Azure CLI installation and authentication
validate_azure_cli() {
    log "Validating Azure CLI installation and authentication..."
    
    case "$OSTYPE" in
        msys*|cygwin*)
            AZ="/c/Users/fennes2/azure-cli-2.75.0-x64/bin/az.cmd"
            ;;
        darwin*)
            AZ="az"   # On macOS, installed via brew
            ;;
        *)
            AZ="az"   # Default for Linux
            ;;
    esac
    
    # Check if Azure CLI exists
    if ! command_exists "$AZ"; then
        log_error "Azure CLI not found at: $AZ"
        log_error "Please install Azure CLI or update the path"
        return 1
    fi
    
    # Check if user is logged in
    if ! "$AZ" account show &>/dev/null; then
        log_error "Not logged in to Azure CLI. Please run: $AZ login --allow-no-subscriptions"
        return 1
    fi
    
    log_success "Azure CLI validated successfully"
    return 0
}

# Function to setup Azure DevOps repository
setup_azure_devops() {
    log "Setting up Azure DevOps repository..."
    
    # Set Azure DevOps org and project
    local organization="https://dev.azure.com/MedtronicBI"
    local project="DigIC GR AI"
    
    # Configure Azure DevOps CLI with error handling
    if ! "$AZ" devops configure --defaults organization="$organization" project="$project"; then
        log_error "Failed to configure Azure DevOps CLI"
        return 1
    fi
    
    # Validate repository name
    while true; do
        read -p "Enter new repository name: " repo_name
        if [[ -z "$repo_name" ]]; then
            log_warning "Repository name cannot be empty. Please try again."
            continue
        fi
        if [[ "$repo_name" =~ [[:space:]] ]]; then
            log_warning "Repository name should not contain spaces. Please use hyphens or underscores."
            continue
        fi
        break
    done
    
    # Check if repository already exists
    if "$AZ" repos show --repository "$repo_name" &>/dev/null; then
        log_error "Repository '$repo_name' already exists in Azure DevOps"
        read -p "Do you want to use a different name? (y/n): " use_different_name
        if [[ "$use_different_name" == "y" || "$use_different_name" == "Y" ]]; then
            setup_azure_devops  # Recursive call to re-enter repository name
            return $?
        else
            return 1
        fi
    fi
    
    # Create the new repository in Azure DevOps
    log "Creating repository '$repo_name' in Azure DevOps..."
    if ! "$AZ" repos create --name "$repo_name"; then
        log_error "Failed to create repository in Azure DevOps"
        return 1
    fi
    
    # URL encode the project name (replace spaces with %20)
    remote_project=$(echo "$project" | sed 's/ /%20/g')
    
    # Build the correct remote URL
    remote_url="$organization/$remote_project/_git/$repo_name"
    
    log_success "Azure DevOps repository created successfully"
    
    # Export variables for use in other functions
    export REPO_NAME="$repo_name"
    export REMOTE_URL="$remote_url"
    
    return 0
}

# Function to setup git repository
setup_git_repository() {
    log "Setting up local git repository..."
    
    # Check if git is installed
    if ! command_exists git; then
        log_error "Git is not installed. Please install Git first."
        return 1
    fi
    
    # Check if we're already in a git repository
    if [[ -d .git ]]; then
        log_warning "Already in a git repository. Continuing..."
    else
        # Initialize local git repository
        if ! git init; then
            log_error "Failed to initialize git repository"
            return 1
        fi
    fi
    
    # Add all files
    if ! git add .; then
        log_error "Failed to add files to git"
        return 1
    fi
    
    # Create initial commit
    if ! git commit -m "Initial commit: project template"; then
        log_error "Failed to create initial commit"
        return 1
    fi
    
    # Rename branch to main
    if ! git branch -M main; then
        log_error "Failed to rename branch to main"
        return 1
    fi
    
    # Add remote origin
    if ! git remote add origin "$REMOTE_URL"; then
        log_error "Failed to add remote origin"
        return 1
    fi
    
    # Push to main branch with retry mechanism
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if git push -u origin main; then
            log_success "Successfully pushed to main branch"
            break
        else
            retry_count=$((retry_count + 1))
            log_warning "Push failed (attempt $retry_count/$max_retries). Retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        log_error "Failed to push to main branch after $max_retries attempts"
        return 1
    fi
    
    return 0
}

# Function to create additional branches
create_branches() {
    log "Creating additional branches (stage, dev)..."
    
    local branches=("stage" "dev")
    
    for branch in "${branches[@]}"; do
        # Create and push branch if it doesn't exist
        if ! git branch --list | grep -q "$branch"; then
            log "Creating and pushing '$branch' branch..."
            
            if ! git checkout -b "$branch"; then
                log_error "Failed to create '$branch' branch"
                return 1
            fi
            
            if ! git push -u origin "$branch"; then
                log_error "Failed to push '$branch' branch"
                return 1
            fi
            
            log_success "'$branch' branch created and pushed successfully"
        else
            log_warning "'$branch' branch already exists"
        fi
    done
    
    # Return to main branch
    if ! git checkout main; then
        log_error "Failed to return to main branch"
        return 1
    fi
    
    return 0
}

# Main Azure DevOps setup
main_azure_setup() {
    log "Starting Azure DevOps setup..."
    
    if ! validate_azure_cli; then
        return 1
    fi
    
    if ! setup_azure_devops; then
        return 1
    fi
    
    if ! setup_git_repository; then
        return 1
    fi
    
    if ! create_branches; then
        return 1
    fi
    
    log_success "Azure DevOps setup completed successfully!"
    log_success "Repository '$REPO_NAME' created with main, stage, and dev branches"
    
    return 0
}

# Execute Azure DevOps setup
if ! main_azure_setup; then
    log_error "Azure DevOps setup failed. Exiting..."
    exit 1
fi

# Function to setup Snowflake integration
setup_snowflake() {
    log "Setting up Snowflake integration..."
    
    # Check if Snowflake CLI (snow) is installed
    if ! command_exists snow; then
        log_error "Snowflake CLI ('snow') is not installed"
        log_error "Please install it from: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation"
        return 1
    fi
    
    # Prompt for Snowflake passphrase with validation
    local passphrase
    local max_attempts=3
    local attempt=1
    
    log "Please provide your Snowflake private key passphrase to test the connection..."
    
    while [[ $attempt -le $max_attempts ]]; do
        read -s -p "Enter Snowflake private key passphrase (attempt $attempt/$max_attempts): " passphrase
        echo
        
        if [[ -z "$passphrase" ]]; then
            log_warning "Passphrase cannot be empty"
            attempt=$((attempt + 1))
            continue
        fi
        
        # Test the passphrase by exporting it and testing connection
        export PRIVATE_KEY_PASSPHRASE="$passphrase"
        
        # Test connection with the passphrase
        log "Testing Snowflake connection with provided passphrase..."
        if snow connection test -c service_principal &>/dev/null; then
            log_success "Snowflake authentication successful"
            break
        else
            log_error "Invalid passphrase or connection failed"
            log_error "Please check that 'service_principal' connection is configured correctly"
            unset PRIVATE_KEY_PASSPHRASE
            attempt=$((attempt + 1))
            
            if [[ $attempt -le $max_attempts ]]; then
                log_warning "Please try again..."
            fi
        fi
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        log_error "Failed to authenticate with Snowflake after $max_attempts attempts"
        log_error "Please have a look at the CICD ReportOut document for more information"
        return 1
    fi
    
    # Create Git repository object in Snowflake
    local sf_cmd="
CREATE GIT REPOSITORY IF NOT EXISTS $REPO_NAME
  ORIGIN = '$REMOTE_URL'
  API_INTEGRATION = API_GR_GIT_AZURE_DEVOPS
  GIT_CREDENTIALS = EMEA_UTILITY_DB.SECRETS.SECRET_GR_GIT_AZURE_DEVOPS;
"
    
    log "Creating Git repository object in Snowflake..."
    if ! snow sql -c service_principal --query "$sf_cmd"; then
        log_error "Failed to create Git repository object in Snowflake"
        unset PRIVATE_KEY_PASSPHRASE
        return 1
    fi
    
    log_success "Git repository object created in Snowflake"
    
    # Setup schema in DEV environment only
    # Stage and Prod schemas will be created automatically on deployment via deploy_sql.py
    local database="DEV_GR_AI_DB"
    local role="GR_AI_ENGINEER"
    
    log "Creating schema and assigning grants in $database..."
    
    # Use database
    if ! snow sql -c service_principal --query "USE DATABASE $database"; then
        log_error "Failed to use database $database"
        unset PRIVATE_KEY_PASSPHRASE
        return 1
    fi
    
    # Create schema
    if ! snow sql -c service_principal --query "CREATE SCHEMA IF NOT EXISTS $database.$REPO_NAME"; then
        log_error "Failed to create schema $database.$REPO_NAME"
        unset PRIVATE_KEY_PASSPHRASE
        return 1
    fi
    
    # Grant privileges
    if ! snow sql -c service_principal --query "GRANT ALL PRIVILEGES ON SCHEMA $database.$REPO_NAME TO ROLE $role"; then
        log_error "Failed to grant privileges on schema $database.$REPO_NAME to role $role"
        unset PRIVATE_KEY_PASSPHRASE
        return 1
    fi
    
    log_success "Schema and grants configured for $database"
    
    # Clean up sensitive environment variable
    unset PRIVATE_KEY_PASSPHRASE
    
    log_success "Snowflake integration completed successfully"
    return 0
}

# Function to validate Databricks CLI installation and configuration
validate_databricks_cli() {
    log "Validating Databricks CLI installation and configuration..."
    
    # Check if Databricks CLI is installed
    if ! command_exists databricks; then
        log_error "Databricks CLI is not installed"
        log_error "Please install it from: https://docs.databricks.com/aws/en/dev-tools/cli/install"
        return 1
    fi
    
    while true; do
        # Check required profiles
        local required_profiles=("prod" "stage" "dev")
        local missing_profiles=()
        
        for profile in "${required_profiles[@]}"; do
            if ! databricks --profile "$profile" current-user me &>/dev/null; then
                missing_profiles+=("$profile")
            fi
        done
        
        if [[ {% raw %}${#missing_profiles[@]}{% endraw %} -eq 0 ]]; then
            log_success "Databricks CLI validated successfully"
            return 0
        fi
        
        # Profiles failed - check if it's a network connectivity issue
        log_warning "Failed to validate Databricks CLI profiles: ${missing_profiles[*]}"
        log_warning "This could be due to network connectivity issues."
        
        read -p "Are you connected to Medtronic's network or VPN? (y/n): " network_connected
        
        if [[ "$network_connected" == "y" || "$network_connected" == "Y" ]]; then
            # User claims to be connected - show configuration error
            log_error "Missing or invalid Databricks CLI profile: $required_profile"
            log_error "Please configure the 'dev' profile (see instructions in CICD document)"
            return 1
        else
            # User not connected - offer to retry
            log_warning "Please connect to Medtronic's network or VPN to access Databricks workspaces."
            log_warning "Connecting to Databricks workspaces requires network connectivity."
            
            read -p "After connecting, would you like to try again? (y/n): " try_again
            
            if [[ "$try_again" != "y" && "$try_again" != "Y" ]]; then
                log_warning "Databricks CLI validation skipped due to network connectivity."
                return 1
            fi
            
            log "Retrying Databricks CLI validation..."
            # Continue the while loop to retry
        fi
    done
}

# Function to setup Databricks integration
setup_databricks() {
    log "Setting up Databricks integration..."
    
    if ! validate_databricks_cli; then
        return 1
    fi
    
    # Get and validate username
    local user_name
    while true; do
        read -p "Enter your Medtronic username (e.g. fennes2 for Siem Fenne): " user_name
        if [[ -z "$user_name" ]]; then
            log_warning "Username cannot be empty. Please try again."
            continue
        fi
        if [[ ! "$user_name" =~ ^[a-zA-Z0-9]+$ ]]; then
            log_warning "Username should only contain alphanumeric characters. Please try again."
            continue
        fi
        break
    done
    
    local dbx_email="$user_name@medtronic.com"
    local dbx_path
    
    # Set path based on OS
    if [[ "$OSTYPE" == darwin* ]]; then
        dbx_path="/Workspace/Users/$dbx_email/$REPO_NAME"
    else
        dbx_path="//Workspace/Users/$dbx_email/$REPO_NAME"
    fi
    
    # Function to get profile for environment
    profile_for_env() {
        case "$1" in
            PROD)  echo "prod"  ;;
            STAGE) echo "stage" ;;
            DEV)   echo "dev"   ;;
            *)     echo "dev"   ;;
        esac
    }
    
    # Setup repository in DEV environment only
    # Stage and Prod workspace connections will be created automatically on deployment via azure-pipeline-dbx.yml
    local environments=("DEV")
    local failed_envs=()
    
    for env in "${environments[@]}"; do
        local profile
        profile="$(profile_for_env "$env")"
        
        log "Linking repository in Databricks $env environment with CLI profile '$profile'..."
        
        # Try to create the repository with detailed error handling
        local create_output
        if create_output=$(databricks --profile "$profile" repos create "$REMOTE_URL" azureDevOpsServices --path "$dbx_path" 2>&1); then
            log_success "Successfully linked to Databricks $env at $dbx_path"
        else
            # Check if the error is because repository already exists
            if echo "$create_output" | grep -qi "already exists\|path.*exists"; then
                log_warning "Repository already exists in Databricks $env at $dbx_path"
            else
                log_error "Failed to create repository in Databricks $env: $create_output"
                failed_envs+=("$env")
            fi
        fi
    done
    
    # Report results
    if [[ {% raw %}${#failed_envs[@]}{% endraw %} -eq 0 ]]; then
        log_success "Databricks integration completed successfully for all environments"
        return 0
    else
        log_error "Databricks integration failed for environments: ${failed_envs[*]}"
        log_warning "You may need to manually configure these environments or check your permissions"
        return 1
    fi
}

# Main integration setup
log "=== Repository Integration Setup ==="
echo

read -p "Do you want to link this repo in Snowflake? (y/n): " setupSnowflake
read -p "Do you want to link this repo in Databricks? (y/n): " setupDatabricks

# Track integration results
snowflake_success=false
databricks_success=false

if [[ "$setupSnowflake" == "y" || "$setupSnowflake" == "Y" ]]; then
    if setup_snowflake; then
        snowflake_success=true
    else
        log_error "Snowflake setup failed, but continuing with other integrations..."
    fi
fi

if [[ "$setupDatabricks" == "y" || "$setupDatabricks" == "Y" ]]; then
    if setup_databricks; then
        databricks_success=true
    else
        log_error "Databricks setup failed, but continuing..."
    fi
fi

# Final summary
echo
log "=== Setup Summary ==="
log_success "Azure DevOps setup completed successfully!"
log_success "Repository: $REPO_NAME"
log_success "Remote URL: $REMOTE_URL"
log_success "Branches created: main, stage, dev"

echo
log "Integration Status:"
if [[ "$setupSnowflake" == "y" || "$setupSnowflake" == "Y" ]]; then
    if [[ "$snowflake_success" == "true" ]]; then
        log_success "Snowflake integration completed successfully"
    else
        log_error "Snowflake integration failed"
    fi
fi

if [[ "$setupDatabricks" == "y" || "$setupDatabricks" == "Y" ]]; then
    if [[ "$databricks_success" == "true" ]]; then
        log_success "Databricks integration completed successfully" 
    else
        log_error "Databricks integration failed"
    fi
fi

# Overall status message
echo
if [[ ("$setupSnowflake" != "y" && "$setupSnowflake" != "Y") && ("$setupDatabricks" != "y" && "$setupDatabricks" != "Y") ]]; then
    log_success "Project setup completed! Your project is ready for development."
elif [[ ("$setupSnowflake" != "y" && "$setupSnowflake" != "Y") || "$snowflake_success" == "true" ]] && [[ ("$setupDatabricks" != "y" && "$setupDatabricks" != "Y") || "$databricks_success" == "true" ]]; then
    log_success "Project setup completed successfully! Your project is ready for development."
else
    log_warning "Something went wrong in the setup process. Please have a look at the ERROR messages above."
fi