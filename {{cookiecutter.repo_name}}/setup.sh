#!/bin/bash

# Setup script for connecting the project to GitHub
# Exit on any error, but we'll handle errors gracefully where needed
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Function to validate GitHub CLI installation and authentication
validate_github_cli() {
    log "Validating GitHub CLI installation and authentication..."

    # Check if GitHub CLI exists
    if ! command_exists gh; then
        log_error "GitHub CLI (gh) not found"
        log_error "Please install it from: https://cli.github.com/"
        return 1
    fi

    # Check if user is logged in
    if ! gh auth status &>/dev/null; then
        log_error "Not logged in to GitHub CLI. Please run: gh auth login"
        return 1
    fi

    log_success "GitHub CLI validated successfully"
    return 0
}

# Function to setup GitHub repository
setup_github_repo() {
    log "Setting up GitHub repository..."

    # Prompt for repository visibility
    read -p "Should the repository be private? (y/n): " is_private
    local visibility="--public"
    if [[ "$is_private" == "y" || "$is_private" == "Y" ]]; then
        visibility="--private"
    fi

    # Validate repository name
    while true; do
        read -p "Enter new repository name (leave empty to use current directory name): " repo_name
        if [[ -z "$repo_name" ]]; then
            repo_name=$(basename "$(pwd)")
            log "Using current directory name: $repo_name"
        fi
        if [[ "$repo_name" =~ [[:space:]] ]]; then
            log_warning "Repository name should not contain spaces. Please use hyphens or underscores."
            continue
        fi
        break
    done

    # Check if repository already exists on GitHub
    if gh repo view "$repo_name" &>/dev/null; then
        log_error "Repository '$repo_name' already exists on GitHub"
        read -p "Do you want to use a different name? (y/n): " use_different_name
        if [[ "$use_different_name" == "y" || "$use_different_name" == "Y" ]]; then
            setup_github_repo  # Recursive call to re-enter repository name
            return $?
        else
            return 1
        fi
    fi

    # Export variable for use in other functions
    export REPO_NAME="$repo_name"
    export REPO_VISIBILITY="$visibility"

    log_success "Repository name validated: $REPO_NAME"
    return 0
}

# Function to setup local git repository and push to GitHub
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

    # Create the GitHub repository and push in one step
    log "Creating GitHub repository '$REPO_NAME' and pushing..."
    if ! gh repo create "$REPO_NAME" $REPO_VISIBILITY --source=. --remote=origin --push; then
        log_error "Failed to create GitHub repository and push"
        return 1
    fi

    log_success "GitHub repository created and code pushed to main"

    # Get the remote URL for display
    REMOTE_URL=$(git remote get-url origin)
    export REMOTE_URL

    return 0
}

# Function to create additional branches
create_branches() {
    log "Creating additional branches (dev, stage)..."

    local branches=("dev" "stage")

    for branch in "${branches[@]}"; do
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

# Main GitHub setup
main_github_setup() {
    log "Starting GitHub repository setup..."

    if ! validate_github_cli; then
        return 1
    fi

    if ! setup_github_repo; then
        return 1
    fi

    if ! setup_git_repository; then
        return 1
    fi

    if ! create_branches; then
        return 1
    fi

    log_success "GitHub setup completed successfully!"
    log_success "Repository '$REPO_NAME' created with main (default), dev, and stage branches"

    return 0
}

# Execute GitHub setup
if ! main_github_setup; then
    log_error "GitHub setup failed. Exiting..."
    exit 1
fi

# Final summary
echo
log "=== Setup Summary ==="
log_success "GitHub repository created successfully!"
log_success "Repository: $REPO_NAME"
log_success "Remote URL: $REMOTE_URL"
log_success "Branches created: main (default), dev, stage"
echo
log_success "Project setup completed! Your project is ready for development."