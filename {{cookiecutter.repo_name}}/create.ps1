# PowerShell Create Script
# Creates notebooks or Streamlit apps with git and Snowflake integration

# Set error handling
$ErrorActionPreference = "Continue"

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to create an empty notebook
function Create-NotebookTemplate {
    param(
        [string]$NotebookPath,
        [string]$NotebookName
    )
    
    $notebookContent = @'
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
'@
    
    $notebookContent | Out-File -FilePath $NotebookPath -Encoding UTF8
}

# Function to create an empty streamlit app
function Create-StreamlitTemplate {
    param(
        [string]$StreamlitPath,
        [string]$AppName
    )
    
    # Create empty file
    New-Item -ItemType File -Path $StreamlitPath -Force | Out-Null
}

# Function to validate input
function Test-Name {
    param([string]$Name)
    
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Error "Name cannot be empty"
        return $false
    }
    
    if ($Name -notmatch '^[a-zA-Z0-9_-]+$') {
        Write-Error "Name can only contain letters, numbers, underscores, and hyphens"
        return $false
    }
    
    return $true
}

# Function to get secure string input (for passphrase)
function Get-SecureInput {
    param([string]$Prompt)
    
    Write-Host $Prompt -NoNewline
    $secureString = Read-Host -AsSecureString
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
    $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    
    return $plainText
}

# Main script
Write-Info "Create or Connect Notebook / Streamlit App"
Write-Host ""

# Get repo name (current directory name)
$REPO_NAME = Split-Path -Leaf (Get-Location)
Write-Info "Repository: $REPO_NAME"

# Get current branch
try {
    $CURRENT_BRANCH = & git rev-parse --abbrev-ref HEAD 2>$null
    if (-not $CURRENT_BRANCH) {
        $CURRENT_BRANCH = "main"
    }
} catch {
    $CURRENT_BRANCH = "main"
}
Write-Info "Current branch: $CURRENT_BRANCH"

# Check if we're on the dev branch
if ($CURRENT_BRANCH -ne "dev") {
    Write-Host ""
    Write-Error "This script can only be run on the 'dev' branch"
    Write-Error "Current branch: $CURRENT_BRANCH"
    Write-Info "Please switch to the 'dev' branch first:"
    Write-Info "  git checkout dev"
    Write-Host ""
    exit 1
}

# Ask whether to create new or connect existing
Write-Host ""
Write-Info "Would you like to create a new file or connect an existing one?"
Write-Host "1) Create new (creates the file and connects to Azure DevOps + Snowflake)"
Write-Host "2) Connect existing (file already exists locally, just connect to Azure DevOps + Snowflake)"
$modeChoice = Read-Host "Enter your choice (1-2)"

$CREATE_NEW = $false
switch ($modeChoice) {
    "1" {
        $CREATE_NEW = $true
    }
    "2" {
        $CREATE_NEW = $false
    }
    default {
        Write-Error "Invalid choice. Exiting."
        exit 1
    }
}

# Ask what type to create/connect
Write-Host ""
if ($CREATE_NEW) {
    Write-Info "What would you like to create? (Your current branch: $CURRENT_BRANCH)"
} else {
    Write-Info "What would you like to connect? (Your current branch: $CURRENT_BRANCH)"
}
Write-Host "1) Notebook"
Write-Host "2) Streamlit App"  
Write-Host "3) Both"
$choice = Read-Host "Enter your choice (1-3)"

$CREATE_NOTEBOOK = $false
$CREATE_STREAMLIT = $false

switch ($choice) {
    "1" {
        $CREATE_NOTEBOOK = $true
    }
    "2" {
        $CREATE_STREAMLIT = $true
    }
    "3" {
        $CREATE_NOTEBOOK = $true
        $CREATE_STREAMLIT = $true
    }
    default {
        Write-Error "Invalid choice. Exiting."
        exit 1
    }
}

# Get notebook name if needed
if ($CREATE_NOTEBOOK) {
    Write-Host ""
    do {
        $NOTEBOOK_NAME = Read-Host "Enter notebook name (without .ipynb extension)"
    } while (-not (Test-Name $NOTEBOOK_NAME))
}

# Get streamlit app name if needed
if ($CREATE_STREAMLIT) {
    Write-Host ""
    do {
        $STREAMLIT_NAME = Read-Host "Enter Streamlit app name (folder name)"
    } while (-not (Test-Name $STREAMLIT_NAME))
}

# Get commit message
Write-Host ""
$COMMIT_MESSAGE = Read-Host "Enter git commit message"
if ([string]::IsNullOrWhiteSpace($COMMIT_MESSAGE)) {
    $COMMIT_MESSAGE = "Add new files via create.ps1 script"
}

Write-Host ""
Write-Info "Summary:"
if ($CREATE_NEW) {
    if ($CREATE_NOTEBOOK) { Write-Info "  - Will create notebook: ${NOTEBOOK_NAME}.ipynb" }
    if ($CREATE_STREAMLIT) { Write-Info "  - Will create Streamlit app: $STREAMLIT_NAME" }
} else {
    if ($CREATE_NOTEBOOK) { Write-Info "  - Will connect existing notebook: ${NOTEBOOK_NAME}.ipynb" }
    if ($CREATE_STREAMLIT) { Write-Info "  - Will connect existing Streamlit app: $STREAMLIT_NAME" }
}
Write-Info "  - Commit message: $COMMIT_MESSAGE"
Write-Host ""

$confirm = Read-Host "Proceed? (y/N)"
if ($confirm -notmatch '^[Yy]$') {
    Write-Info "Operation cancelled."
    exit 0
}

# Create or verify files
Write-Host ""
if ($CREATE_NEW) {
    Write-Info "Creating files..."
} else {
    Write-Info "Verifying existing files..."
}

if ($CREATE_NOTEBOOK) {
    $NOTEBOOK_PATH = "notebooks\${NOTEBOOK_NAME}.ipynb"
    
    if ($CREATE_NEW) {
        # Create notebooks directory if it doesn't exist
        if (-not (Test-Path "notebooks")) {
            New-Item -ItemType Directory -Path "notebooks" -Force | Out-Null
        }
        
        if (Test-Path $NOTEBOOK_PATH) {
            Write-Warning "Notebook $NOTEBOOK_PATH already exists. Overwriting..."
        }
        
        Create-NotebookTemplate -NotebookPath $NOTEBOOK_PATH -NotebookName $NOTEBOOK_NAME
        Write-Success "Created notebook: $NOTEBOOK_PATH"
    } else {
        # Verify notebook exists
        if (-not (Test-Path $NOTEBOOK_PATH)) {
            Write-Error "Notebook $NOTEBOOK_PATH does not exist!"
            Write-Error "Please make sure the file exists or choose 'Create new' instead."
            exit 1
        }
        Write-Success "Found existing notebook: $NOTEBOOK_PATH"
    }
}

if ($CREATE_STREAMLIT) {
    $STREAMLIT_DIR = "streamlit\$STREAMLIT_NAME"
    $STREAMLIT_PATH = "$STREAMLIT_DIR\streamlit_app.py"
    
    if ($CREATE_NEW) {
        # Create streamlit directory structure
        if (-not (Test-Path $STREAMLIT_DIR)) {
            New-Item -ItemType Directory -Path $STREAMLIT_DIR -Force | Out-Null
        }
        
        if (Test-Path $STREAMLIT_PATH) {
            Write-Warning "Streamlit app $STREAMLIT_PATH already exists. Overwriting..."
        }
        
        Create-StreamlitTemplate -StreamlitPath $STREAMLIT_PATH -AppName $STREAMLIT_NAME
        Write-Success "Created Streamlit app: $STREAMLIT_PATH"
    } else {
        # Verify streamlit app exists
        if (-not (Test-Path $STREAMLIT_PATH)) {
            Write-Error "Streamlit app $STREAMLIT_PATH does not exist!"
            Write-Error "Please make sure the file exists or choose 'Create new' instead."
            exit 1
        }
        Write-Success "Found existing Streamlit app: $STREAMLIT_PATH"
    }
}

# Git operations
Write-Host ""
Write-Info "Performing git operations..."

# Check if git repo exists
try {
    & git rev-parse --git-dir 2>$null | Out-Null
} catch {
    Write-Error "Not a git repository. Please initialize git first."
    exit 1
}

# Pull latest changes from remote
Write-Info "Pulling latest changes from remote..."
$gitPullResult = & git pull 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "Successfully pulled remote changes"
} else {
    Write-Warning "Failed to pull remote changes or no remote configured. Continuing..."
}

# Add files
$gitAddResult = & git add . 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "Files added to git staging"
} else {
    Write-Error "Failed to add files to git"
    exit 1
}

# Commit
$gitCommitResult = & git commit -m $COMMIT_MESSAGE 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "Changes committed"
} else {
    Write-Error "Failed to commit changes"
    exit 1
}

# Push
$gitPushResult = & git push 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "Changes pushed to remote"
} else {
    Write-Error "Failed to push changes"
    exit 1
}

# Snowflake operations
Write-Host ""
Write-Info "Performing Snowflake operations..."

# Check if snowflake CLI is available
try {
    & snow --version 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Command not found"
    }
} catch {
    Write-Error "Snowflake CLI not found. Please install it first."
    exit 1
}

# Prompt for Snowflake passphrase with validation
$passphrase = ""
$maxAttempts = 3
$attempt = 1

Write-Info "Please provide your Snowflake private key passphrase to authenticate..."

while ($attempt -le $maxAttempts) {
    $passphrase = Get-SecureInput "Enter Snowflake private key passphrase (attempt $attempt/$maxAttempts): "
    Write-Host ""
    
    if ([string]::IsNullOrWhiteSpace($passphrase)) {
        Write-Warning "Passphrase cannot be empty"
        $attempt++
        continue
    }
    
    # Test the passphrase by exporting it and testing connection
    $env:PRIVATE_KEY_PASSPHRASE = $passphrase
    
    # Test connection with the passphrase
    Write-Info "Testing Snowflake connection with provided passphrase..."
    $testResult = & snow connection test -c service_principal 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Snowflake authentication successful"
        break
    } else {
        Write-Error "Invalid passphrase or connection failed"
        Write-Error "Please check that 'service_principal' connection is configured correctly"
        Remove-Item Env:\PRIVATE_KEY_PASSPHRASE -ErrorAction SilentlyContinue
        $attempt++
        
        if ($attempt -le $maxAttempts) {
            Write-Warning "Please try again..."
        }
    }
}

if ($attempt -gt $maxAttempts) {
    Write-Error "Maximum passphrase attempts exceeded. Exiting."
    exit 1
}

# Git fetch in Snowflake
Write-Info "Fetching git repository in Snowflake..."
$SNOW_FETCH_CMD = "snow git fetch `"EMEA_UTILITY_DB.GIT_REPOSITORIES.$REPO_NAME`" --connection service_principal"
Write-Host "Executing: $SNOW_FETCH_CMD"

$fetchResult = Invoke-Expression $SNOW_FETCH_CMD 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "Git repository fetched in Snowflake"
} else {
    Write-Error "Failed to fetch git repository in Snowflake"
    Remove-Item Env:\PRIVATE_KEY_PASSPHRASE -ErrorAction SilentlyContinue
    exit 1
}

# Create Snowflake objects
if ($CREATE_NOTEBOOK) {
    Write-Host ""
    Write-Info "Creating notebook in Snowflake..."
    
    # Construct the full repo path for notebooks
    $FULL_REPO_PATH = "@EMEA_UTILITY_DB.GIT_REPOSITORIES.$REPO_NAME/branches/$CURRENT_BRANCH/notebooks"
    
    # Use simpler notebook creation syntax to avoid PowerShell quoting issues
    $CREATE_NOTEBOOK_CMD = "CREATE OR REPLACE NOTEBOOK DEV_GR_AI_DB.$REPO_NAME.$NOTEBOOK_NAME FROM '$FULL_REPO_PATH' MAIN_FILE = '$NOTEBOOK_NAME.ipynb' QUERY_WAREHOUSE = NPRD_ANALYTICS_WH;"
    
    Write-Host "Executing SQL:"
    Write-Host $CREATE_NOTEBOOK_CMD
    
    $createNotebookResult = & snow sql -c service_principal --query $CREATE_NOTEBOOK_CMD 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Notebook created in Snowflake"
        
        # Add live version - simplified syntax as well
        $ALTER_NOTEBOOK_CMD = "ALTER NOTEBOOK DEV_GR_AI_DB.$REPO_NAME.$NOTEBOOK_NAME ADD LIVE VERSION FROM LAST;"
        $alterResult = & snow sql -c service_principal --query $ALTER_NOTEBOOK_CMD 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Live version added to notebook"
        } else {
            Write-Warning "Failed to add live version to notebook"
        }
    } else {
        Write-Error "Failed to create notebook in Snowflake"
    }
}

if ($CREATE_STREAMLIT) {
    Write-Host ""
    Write-Info "Creating Streamlit app in Snowflake..."
    
    # Construct the full repo path for streamlit
    $FULL_REPO_PATH = "@EMEA_UTILITY_DB.GIT_REPOSITORIES.$REPO_NAME/branches/$CURRENT_BRANCH/streamlit/$STREAMLIT_NAME"
    $STREAMLIT_OBJECT_NAME = "${REPO_NAME}_${CURRENT_BRANCH}_${STREAMLIT_NAME}"
    
    # Use simpler streamlit creation syntax to avoid PowerShell quoting issues
    $CREATE_STREAMLIT_CMD = "CREATE OR REPLACE STREAMLIT DEV_GR_AI_DB.$REPO_NAME.$STREAMLIT_OBJECT_NAME FROM '$FULL_REPO_PATH' MAIN_FILE = 'streamlit_app.py' QUERY_WAREHOUSE = NPRD_GR_TRANSFORM_WH;"
    
    Write-Host "Executing SQL:"
    Write-Host $CREATE_STREAMLIT_CMD
    
    $createStreamlitResult = & snow sql -c service_principal --query $CREATE_STREAMLIT_CMD 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Streamlit app created in Snowflake"
    } else {
        Write-Error "Failed to create Streamlit app in Snowflake"
    }
}

# Clean up sensitive environment variable
Remove-Item Env:\PRIVATE_KEY_PASSPHRASE -ErrorAction SilentlyContinue

Write-Host ""
Write-Success "All operations completed successfully!"
Write-Host ""
if ($CREATE_NEW) {
    Write-Info "Summary of created objects:"
} else {
    Write-Info "Summary of connected objects:"
}
if ($CREATE_NOTEBOOK) { 
    Write-Info "  - Notebook: notebooks\${NOTEBOOK_NAME}.ipynb"
    Write-Info "  - Snowflake Notebook: DEV_GR_AI_DB.$REPO_NAME.$NOTEBOOK_NAME"
}
if ($CREATE_STREAMLIT) { 
    Write-Info "  - Streamlit App: streamlit\$STREAMLIT_NAME\streamlit_app.py"
    Write-Info "  - Snowflake Streamlit: DEV_GR_AI_DB.$REPO_NAME.${REPO_NAME}_${CURRENT_BRANCH}_${STREAMLIT_NAME}"
}
Write-Host ""
if ($CREATE_NEW) {
    Write-Info "You can now start developing your new files!"
} else {
    Write-Info "Your existing files are now connected to Azure DevOps and Snowflake!"
}