#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
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

# Function to create an empty notebook
create_notebook_template() {
    local notebook_path="$1"
    local notebook_name="$2"
    
    cat > "$notebook_path" << 'EOF'
{
 "cells": [],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "codemirror_mode": {
    "name": "ipython",
    "version": 3
   },
   "file_extension": ".py",
   "mimetype": "text/x-python",
   "name": "python",
   "nbconvert_exporter": "python",
   "pygments_lexer": "ipython3",
   "version": "3.9.0"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EOF
}

# Function to create an empty streamlit app
create_streamlit_template() {
    local streamlit_path="$1"
    local app_name="$2"
    
    # Create empty file
    touch "$streamlit_path"
}

# Function to validate input
validate_name() {
    local name="$1"
    if [[ -z "$name" ]]; then
        log_error "Name cannot be empty"
        return 1
    fi
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Name can only contain letters, numbers, underscores, and hyphens"
        return 1
    fi
    return 0
}

# Main script
log_info "Create New Notebook or Streamlit App"
echo

# Get repo name (current directory name)
REPO_NAME=$(basename "$(pwd)")
log_info "Repository: $REPO_NAME"

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
log_info "Current branch: $CURRENT_BRANCH"

# Ask what to create
echo
log_info "What would you like to create? (Your current branch: $CURRENT_BRANCH)"
echo "1) Notebook"
echo "2) Streamlit App"
echo "3) Both"
read -p "Enter your choice (1-3): " choice

CREATE_NOTEBOOK=false
CREATE_STREAMLIT=false

case $choice in
    1)
        CREATE_NOTEBOOK=true
        ;;
    2)
        CREATE_STREAMLIT=true
        ;;
    3)
        CREATE_NOTEBOOK=true
        CREATE_STREAMLIT=true
        ;;
    *)
        log_error "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Get notebook name if needed
if [ "$CREATE_NOTEBOOK" = true ]; then
    echo
    while true; do
        read -p "Enter notebook name (without .ipynb extension): " NOTEBOOK_NAME
        if validate_name "$NOTEBOOK_NAME"; then
            break
        fi
    done
fi

# Get streamlit app name if needed
if [ "$CREATE_STREAMLIT" = true ]; then
    echo
    while true; do
        read -p "Enter Streamlit app name (folder name): " STREAMLIT_NAME
        if validate_name "$STREAMLIT_NAME"; then
            break
        fi
    done
fi

# Get commit message
echo
read -p "Enter git commit message: " COMMIT_MESSAGE
if [[ -z "$COMMIT_MESSAGE" ]]; then
    COMMIT_MESSAGE="Add new files via create.sh script"
fi

echo
log_info "Summary:"
[ "$CREATE_NOTEBOOK" = true ] && log_info "  - Will create notebook: ${NOTEBOOK_NAME}.ipynb"
[ "$CREATE_STREAMLIT" = true ] && log_info "  - Will create Streamlit app: $STREAMLIT_NAME"
log_info "  - Commit message: $COMMIT_MESSAGE"
echo

read -p "Proceed? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "Operation cancelled."
    exit 0
fi

# Create files
echo
log_info "Creating files..."

if [ "$CREATE_NOTEBOOK" = true ]; then
    # Create notebooks directory if it doesn't exist
    mkdir -p notebooks
    
    NOTEBOOK_PATH="notebooks/${NOTEBOOK_NAME}.ipynb"
    if [ -f "$NOTEBOOK_PATH" ]; then
        log_warning "Notebook $NOTEBOOK_PATH already exists. Overwriting..."
    fi
    
    create_notebook_template "$NOTEBOOK_PATH" "$NOTEBOOK_NAME"
    log_success "Created notebook: $NOTEBOOK_PATH"
fi

if [ "$CREATE_STREAMLIT" = true ]; then
    # Create streamlit directory structure
    STREAMLIT_DIR="streamlit/${STREAMLIT_NAME}"
    mkdir -p "$STREAMLIT_DIR"
    
    STREAMLIT_PATH="${STREAMLIT_DIR}/streamlit_app.py"
    if [ -f "$STREAMLIT_PATH" ]; then
        log_warning "Streamlit app $STREAMLIT_PATH already exists. Overwriting..."
    fi
    
    create_streamlit_template "$STREAMLIT_PATH" "$STREAMLIT_NAME"
    log_success "Created Streamlit app: $STREAMLIT_PATH"
fi

# Git operations
echo
log_info "Performing git operations..."

# Check if git repo exists
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not a git repository. Please initialize git first."
    exit 1
fi

# Pull latest changes from remote
log_info "Pulling latest changes from remote..."
git pull
if [ $? -eq 0 ]; then
    log_success "Successfully pulled remote changes"
else
    log_warning "Failed to pull remote changes or no remote configured. Continuing..."
fi

# Add files
git add .
if [ $? -eq 0 ]; then
    log_success "Files added to git staging"
else
    log_error "Failed to add files to git"
    exit 1
fi

# Commit
git commit -m "$COMMIT_MESSAGE"
if [ $? -eq 0 ]; then
    log_success "Changes committed"
else
    log_error "Failed to commit changes"
    exit 1
fi

# Push
git push
if [ $? -eq 0 ]; then
    log_success "Changes pushed to remote"
else
    log_error "Failed to push changes"
    exit 1
fi

# Snowflake operations
echo
log_info "❄️  Performing Snowflake operations..."

# Check if snowflake CLI is available
if ! command -v snow &> /dev/null; then
    log_error "Snowflake CLI not found. Please install it first."
    exit 1
fi

# Prompt for Snowflake passphrase with validation
passphrase=""
max_attempts=3
attempt=1

log_info "Please provide your Snowflake private key passphrase to authenticate..."

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
    log_info "Testing Snowflake connection with provided passphrase..."
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
    log_error "Maximum passphrase attempts exceeded. Exiting."
    exit 1
fi

# Git fetch in Snowflake
log_info "Fetching git repository in Snowflake..."
SNOW_FETCH_CMD="snow git fetch \"EMEA_UTILITY_DB.GIT_REPOSITORIES.${REPO_NAME}\" --connection service_principal"
echo "Executing: $SNOW_FETCH_CMD"

if eval "$SNOW_FETCH_CMD"; then
    log_success "Git repository fetched in Snowflake"
else
    log_error "Failed to fetch git repository in Snowflake"
    unset PRIVATE_KEY_PASSPHRASE
    exit 1
fi

# Create Snowflake objects
if [ "$CREATE_NOTEBOOK" = true ]; then
    echo
    log_info "Creating notebook in Snowflake..."
    
    # Construct the full repo path for notebooks
    FULL_REPO_PATH="@\"EMEA_UTILITY_DB\".\"GIT_REPOSITORIES\".\"${REPO_NAME}\"/branches/${CURRENT_BRANCH}/notebooks/"
    
    CREATE_NOTEBOOK_CMD="CREATE OR REPLACE NOTEBOOK IDENTIFIER('\"DEV_GR_AI_DB\".\"${REPO_NAME}\".\"${NOTEBOOK_NAME}\"')
FROM ${FULL_REPO_PATH}
WAREHOUSE = 'NPRD_ANALYTICS_WH'
QUERY_WAREHOUSE = 'NPRD_ANALYTICS_WH'
RUNTIME_NAME = 'SYSTEM\$WAREHOUSE_RUNTIME'
MAIN_FILE = '${NOTEBOOK_NAME}.ipynb';"
    
    echo "Executing SQL:"
    echo "$CREATE_NOTEBOOK_CMD"
    
    if snow sql -c service_principal --query "$CREATE_NOTEBOOK_CMD"; then
        log_success "Notebook created in Snowflake"
        
        # Add live version
        ALTER_NOTEBOOK_CMD="ALTER NOTEBOOK \"DEV_GR_AI_DB\".\"${REPO_NAME}\".\"${NOTEBOOK_NAME}\" ADD LIVE VERSION FROM LAST;"
        if snow sql -c service_principal --query "$ALTER_NOTEBOOK_CMD"; then
            log_success "Live version added to notebook"
        else
            log_warning "Failed to add live version to notebook"
        fi
    else
        log_error "Failed to create notebook in Snowflake"
    fi
fi

if [ "$CREATE_STREAMLIT" = true ]; then
    echo
    log_info "Creating Streamlit app in Snowflake..."
    
    # Construct the full repo path for streamlit
    FULL_REPO_PATH="@\"EMEA_UTILITY_DB\".\"GIT_REPOSITORIES\".\"${REPO_NAME}\"/branches/${CURRENT_BRANCH}/streamlit/${STREAMLIT_NAME}/"
    STREAMLIT_OBJECT_NAME="${REPO_NAME}_${CURRENT_BRANCH}_${STREAMLIT_NAME}"
    
    CREATE_STREAMLIT_CMD="CREATE OR REPLACE STREAMLIT IDENTIFIER('\"DEV_GR_AI_DB\".\"${REPO_NAME}\".\"${STREAMLIT_OBJECT_NAME}\"')
FROM ${FULL_REPO_PATH}
MAIN_FILE = 'streamlit_app.py'
QUERY_WAREHOUSE = 'NPRD_ANALYTICS_WH';"
    
    echo "Executing SQL:"
    echo "$CREATE_STREAMLIT_CMD"
    
    if snow sql -c service_principal --query "$CREATE_STREAMLIT_CMD"; then
        log_success "Streamlit app created in Snowflake"
    else
        log_error "Failed to create Streamlit app in Snowflake"
    fi
fi

# Clean up sensitive environment variable
unset PRIVATE_KEY_PASSPHRASE

echo
log_success "All operations completed successfully!"
echo
log_info "Summary of created objects:"
[ "$CREATE_NOTEBOOK" = true ] && log_info "  • Notebook: notebooks/${NOTEBOOK_NAME}.ipynb"
[ "$CREATE_NOTEBOOK" = true ] && log_info "  • Snowflake Notebook: DEV_GR_AI_DB.${REPO_NAME}.${NOTEBOOK_NAME}"
[ "$CREATE_STREAMLIT" = true ] && log_info "  • Streamlit App: streamlit/${STREAMLIT_NAME}/streamlit_app.py"
[ "$CREATE_STREAMLIT" = true ] && log_info "  • Snowflake Streamlit: DEV_GR_AI_DB.${REPO_NAME}.${REPO_NAME}_${CURRENT_BRANCH}_${STREAMLIT_NAME}"
echo
log_info "You can now start developing your new files!"
