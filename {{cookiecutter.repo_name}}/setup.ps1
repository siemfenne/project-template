# Enhanced PowerShell setup script with comprehensive error handling
# For Windows systems

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Global variables for logging
$script:REPO_NAME = ""
$script:REMOTE_URL = ""

# Color functions for enhanced output
function Write-Log {
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

# Error handling function
function Handle-Error {
    param([string]$ErrorMessage, [string]$Location = "")
    
    Write-Error "An error occurred: $ErrorMessage"
    if ($Location) {
        Write-Error "Location: $Location"
    }
    Write-Warning "Rolling back any partial changes..."
    Cleanup-OnError
    exit 1
}

# Cleanup function for error scenarios
function Cleanup-OnError {
    Write-Warning "Performing cleanup..."
    
    # Remove git remote if it was added
    try {
        $remoteUrl = git remote get-url origin 2>$null
        if ($remoteUrl) {
            git remote remove origin 2>$null
            Write-Warning "Removed git remote origin"
        }
    } catch {
        # Ignore errors during cleanup
    }
    
    # Check if .git directory exists
    if (Test-Path ".git") {
        Write-Warning "Git repository was initialized but setup failed. Consider running 'Remove-Item -Recurse -Force .git' to reset."
    }
}

# Function to test if a command exists
function Test-CommandExists {
    param([string]$Command)
    
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Function to validate Azure CLI installation and authentication
function Test-AzureCli {
    Write-Log "Validating Azure CLI installation and authentication..."
    
    # Check if Azure CLI exists
    if (-not (Test-CommandExists "az")) {
        Write-Error "Azure CLI is not installed"
        Write-Error "Please install Azure CLI or update the path"
        return $false
    }
    
    # Check if user is logged in
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Not logged in to Azure CLI. Please run: az login --allow-no-subscriptions"
            return $false
        }
    } catch {
        Write-Error "Not logged in to Azure CLI. Please run: az login --allow-no-subscriptions"
        return $false
    }
    
    Write-Success "Azure CLI validated successfully"
    return $true
}

# Function to setup Azure DevOps repository
function Set-AzureDevOpsRepository {
    Write-Log "Setting up Azure DevOps repository..."
    
    # Set Azure DevOps org and project
    $organization = "https://dev.azure.com/MedtronicBI"
    $project = "DigIC GR AI"
    
    # Configure Azure DevOps CLI with error handling
    try {
        az devops configure --defaults organization=$organization project=$project
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to configure Azure DevOps CLI"
        }
    } catch {
        Write-Error "Failed to configure Azure DevOps CLI: $_"
        return $false
    }
    
    # Validate repository name
    do {
        $repo_name = Read-Host "Enter new repository name"
        
        if ([string]::IsNullOrWhiteSpace($repo_name)) {
            Write-Warning "Repository name cannot be empty. Please try again."
            continue
        }
        
        if ($repo_name -match '\s') {
            Write-Warning "Repository name should not contain spaces. Please use hyphens or underscores."
            continue
        }
        
        # Check if repository already exists
        try {
            $existingRepo = az repos show --repository $repo_name 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Error "Repository '$repo_name' already exists in Azure DevOps"
                $useDifferentName = Read-Host "Do you want to use a different name? (y/n)"
                if ($useDifferentName -eq "y" -or $useDifferentName -eq "Y") {
                    continue
                } else {
                    return $false
                }
            }
        } catch {
            # Repository doesn't exist, which is good
        }
        
        break
    } while ($true)
    
    # Create the new repository in Azure DevOps
    Write-Log "Creating repository '$repo_name' in Azure DevOps..."
    try {
        az repos create --name $repo_name
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create repository"
        }
    } catch {
        Write-Error "Failed to create repository in Azure DevOps: $_"
        return $false
    }
    
    # URL encode the project name (replace spaces with %20)
    $remote_project = $project -replace ' ', '%20'
    
    # Build the correct remote URL
    $remote_url = "$organization/$remote_project/_git/$repo_name"
    
    Write-Success "Azure DevOps repository created successfully"
    
    # Set global variables
    $script:REPO_NAME = $repo_name
    $script:REMOTE_URL = $remote_url
    
    return $true
}

# Function to setup git repository
function Set-GitRepository {
    Write-Log "Setting up local git repository..."
    
    # Check if git is installed
    if (-not (Test-CommandExists "git")) {
        Write-Error "Git is not installed. Please install Git first."
        return $false
    }
    
    # Check if we're already in a git repository
    if (Test-Path ".git") {
        Write-Warning "Already in a git repository. Continuing..."
    } else {
        # Initialize local git repository
        try {
            git init
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to initialize git repository"
            }
        } catch {
            Write-Error "Failed to initialize git repository: $_"
            return $false
        }
    }
    
    # Add all files
    try {
        git add .
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to add files to git"
        }
    } catch {
        Write-Error "Failed to add files to git: $_"
        return $false
    }
    
    # Create initial commit
    try {
        git commit -m "Initial commit: project template"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create initial commit"
        }
    } catch {
        Write-Error "Failed to create initial commit: $_"
        return $false
    }
    
    # Rename branch to dev (dev is the default branch)
    try {
        git branch -M dev
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to rename branch to dev"
        }
    } catch {
        Write-Error "Failed to rename branch to dev: $_"
        return $false
    }
    
    # Add remote origin
    try {
        git remote add origin $script:REMOTE_URL
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to add remote origin"
        }
    } catch {
        Write-Error "Failed to add remote origin: $_"
        return $false
    }
    
    # Push to dev branch (default branch) with retry mechanism
    $maxRetries = 3
    $retryCount = 0
    
    while ($retryCount -lt $maxRetries) {
        try {
            git push -u origin dev
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Successfully pushed to dev branch"
                break
            } else {
                throw "Push failed"
            }
        } catch {
            $retryCount++
            Write-Warning "Push failed (attempt $retryCount/$maxRetries). Retrying in 5 seconds..."
            Start-Sleep -Seconds 5
        }
    }
    
    if ($retryCount -eq $maxRetries) {
        Write-Error "Failed to push to dev branch after $maxRetries attempts"
        return $false
    }
    
    return $true
}

# Function to create additional branches
function New-AdditionalBranches {
    Write-Log "Creating additional branches (main, stage)..."
    
    $branches = @("main", "stage")
    
    foreach ($branch in $branches) {
        # Create and push branch if it doesn't exist
        $existingBranch = git branch --list $branch
        if (-not $existingBranch) {
            Write-Log "Creating and pushing '$branch' branch..."
            
            try {
                git checkout -b $branch
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to create '$branch' branch"
                }
                
                git push -u origin $branch
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to push '$branch' branch"
                }
                
                Write-Success "'$branch' branch created and pushed successfully"
            } catch {
                Write-Error "Failed to create '$branch' branch: $_"
                return $false
            }
        } else {
            Write-Warning "'$branch' branch already exists"
        }
    }
    
    # Return to dev branch (default branch)
    try {
        git checkout dev
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to return to dev branch"
        }
    } catch {
        Write-Error "Failed to return to dev branch: $_"
        return $false
    }
    
    return $true
}

# Main Azure DevOps setup
function Start-AzureSetup {
    Write-Log "Starting Azure DevOps setup..."
    
    if (-not (Test-AzureCli)) {
        return $false
    }
    
    if (-not (Set-AzureDevOpsRepository)) {
        return $false
    }
    
    if (-not (Set-GitRepository)) {
        return $false
    }
    
    if (-not (New-AdditionalBranches)) {
        return $false
    }
    
    # Set dev as the default branch in Azure DevOps
    Write-Log "Setting 'dev' as the default branch in Azure DevOps..."
    try {
        az repos update --repository $script:REPO_NAME --default-branch dev 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Default branch set to 'dev' successfully"
        } else {
            Write-Warning "Failed to set default branch to dev - you may need to set this manually"
        }
    } catch {
        Write-Warning "Failed to set default branch to dev - you may need to set this manually"
    }
    
    Write-Success "Azure DevOps setup completed successfully!"
    Write-Success "Repository '$script:REPO_NAME' created with dev (default), main, and stage branches"
    
    return $true
}

# Function to setup Snowflake integration
function Set-SnowflakeIntegration {
    Write-Log "Setting up Snowflake integration..."
    
    # Check if Snowflake CLI (snow) is installed
    if (-not (Test-CommandExists "snow")) {
        Write-Error "Snowflake CLI ('snow') is not installed"
        Write-Error "Please install it from: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation"
        return $false
    }
    
    # Prompt for Snowflake passphrase with validation
    $maxAttempts = 3
    $attempt = 1
    
    Write-Log "Please provide your Snowflake private key passphrase to test the connection..."
    
    while ($attempt -le $maxAttempts) {
        $passphrase = Read-Host -AsSecureString "Enter Snowflake private key passphrase (attempt $attempt/$maxAttempts)"
        
        if ($passphrase.Length -eq 0) {
            Write-Warning "Passphrase cannot be empty"
            $attempt++
            continue
        }
        
        # Convert SecureString to plain text for environment variable
        $unsecurePass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($passphrase))
        $env:PRIVATE_KEY_PASSPHRASE = $unsecurePass
        
        # Test connection with the passphrase
        Write-Log "Testing Snowflake connection with provided passphrase..."
        try {
            snow connection test -c service_principal 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Snowflake authentication successful"
                break
            } else {
                Write-Error "Invalid passphrase or connection failed"
                Write-Error "Please check that 'service_principal' connection is configured correctly"
                Remove-Item Env:PRIVATE_KEY_PASSPHRASE -ErrorAction SilentlyContinue
                $attempt++
                
                if ($attempt -le $maxAttempts) {
                    Write-Warning "Please try again..."
                }
            }
        } catch {
            Write-Error "Invalid passphrase or connection failed"
            Write-Error "Please check that 'service_principal' connection is configured correctly"
            Remove-Item Env:PRIVATE_KEY_PASSPHRASE -ErrorAction SilentlyContinue
            $attempt++
            
            if ($attempt -le $maxAttempts) {
                Write-Warning "Please try again..."
            }
        }
    }
    
    if ($attempt -gt $maxAttempts) {
        Write-Error "Failed to authenticate with Snowflake after $maxAttempts attempts"
        Write-Error "Please have a look at the CICD ReportOut document for more information"
        return $false
    }
    
    # Create Git repository object in Snowflake
    $sf_cmd = @"
CREATE GIT REPOSITORY IF NOT EXISTS $script:REPO_NAME
  ORIGIN = '$script:REMOTE_URL'
  API_INTEGRATION = API_GR_GIT_AZURE_DEVOPS
  GIT_CREDENTIALS = EMEA_UTILITY_DB.SECRETS.SECRET_GR_GIT_AZURE_DEVOPS;
"@
    
    Write-Log "Creating Git repository object in Snowflake..."
    try {
        snow sql -c service_principal --query $sf_cmd
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create Git repository object"
        }
    } catch {
        Write-Error "Failed to create Git repository object in Snowflake"
        Remove-Item Env:PRIVATE_KEY_PASSPHRASE -ErrorAction SilentlyContinue
        return $false
    }
    
    Write-Success "Git repository object created in Snowflake"
    
    # Setup schema in DEV environment only
    # Stage and Prod schemas will be created automatically on deployment via deploy_sql.py
    $database = "DEV_GR_AI_DB"
    $role = "GR_AI_ENGINEER"
    
    Write-Log "Creating schema and assigning grants in $database..."
    
    # Use database
    try {
        snow sql -c service_principal --query "USE DATABASE $database"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to use database $database"
        }
    } catch {
        Write-Error "Failed to use database $database"
        Remove-Item Env:PRIVATE_KEY_PASSPHRASE -ErrorAction SilentlyContinue
        return $false
    }
    
    # Create schema
    try {
        snow sql -c service_principal --query "CREATE SCHEMA IF NOT EXISTS $database.$script:REPO_NAME"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create schema"
        }
    } catch {
        Write-Error "Failed to create schema $database.$script:REPO_NAME"
        Remove-Item Env:PRIVATE_KEY_PASSPHRASE -ErrorAction SilentlyContinue
        return $false
    }
    
    # Grant privileges
    try {
        snow sql -c service_principal --query "GRANT ALL PRIVILEGES ON SCHEMA $database.$script:REPO_NAME TO ROLE $role"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to grant privileges"
        }
    } catch {
        Write-Error "Failed to grant privileges on schema $database.$script:REPO_NAME to role $role"
        Remove-Item Env:PRIVATE_KEY_PASSPHRASE -ErrorAction SilentlyContinue
        return $false
    }
    
    Write-Success "Schema and grants configured for $database"
    
    # Clean up sensitive environment variable
    Remove-Item Env:PRIVATE_KEY_PASSPHRASE -ErrorAction SilentlyContinue
    
    Write-Success "Snowflake integration completed successfully"
    return $true
}

# Function to validate Databricks CLI installation and configuration
function Test-DatabricksCli {
    Write-Log "Validating Databricks CLI installation and configuration..."
    
    # Check if Databricks CLI is installed
    if (-not (Test-CommandExists "databricks")) {
        Write-Error "Databricks CLI is not installed"
        Write-Error "Please install it from: https://docs.databricks.com/aws/en/dev-tools/cli/install"
        return $false
    }
    
    while ($true) {
        # Check required profile (only DEV needed for setup)
        # Stage and Prod profiles are not needed as connections are created via pipeline
        $requiredProfile = "dev"
        
        try {
            # Run from home directory to avoid databricks.yml bundle interference
            $currentDir = Get-Location
            Set-Location $env:USERPROFILE
            
            # Capture output and exit code properly
            $output = databricks --profile $requiredProfile current-user me 2>&1
            $exitCode = $LASTEXITCODE
            $outputString = $output | Out-String
            
            # Return to original directory
            Set-Location $currentDir
            
            # Check if command succeeded
            if ($exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($outputString) -and $outputString -notmatch "Error") {
                Write-Success "Databricks CLI validated successfully"
                return $true
            }
        } catch {
            # Validation failed - ensure we return to original directory
            if ($currentDir) {
                Set-Location $currentDir
            }
        }
        
        # Profile failed - check if it's a network connectivity issue
        Write-Warning "Failed to validate Databricks CLI profile: $requiredProfile"
        Write-Warning "This could be due to network connectivity issues."
        
        $networkConnected = Read-Host "Are you connected to Medtronic's network or VPN? (y/n)"
        
        if ($networkConnected -eq "y" -or $networkConnected -eq "Y") {
            # User claims to be connected - show configuration error
            Write-Error "Missing or invalid Databricks CLI profile: $requiredProfile"
            Write-Error "Please configure the 'dev' profile (see instructions in CICD document)"
            return $false
        } else {
            # User not connected - offer to retry
            Write-Warning "Please connect to Medtronic's network or VPN to access Databricks workspaces."
            Write-Warning "Connecting to Databricks workspaces requires network connectivity."
            
            $tryAgain = Read-Host "After connecting, would you like to try again? (y/n)"
            
            if ($tryAgain -ne "y" -and $tryAgain -ne "Y") {
                Write-Warning "Databricks CLI validation skipped due to network connectivity."
                return $false
            }
            
            Write-Log "Retrying Databricks CLI validation..."
            # Continue the while loop to retry
        }
    }
}

# Function to setup Databricks integration
function Set-DatabricksIntegration {
    Write-Log "Setting up Databricks integration..."
    
    if (-not (Test-DatabricksCli)) {
        return $false
    }
    
    # Get and validate username
    do {
        $user_name = Read-Host "Enter your Medtronic username (e.g. fennes2 for Siem Fenne)"
        if ([string]::IsNullOrWhiteSpace($user_name)) {
            Write-Warning "Username cannot be empty. Please try again."
            continue
        }
        if ($user_name -notmatch '^[a-zA-Z0-9]+$') {
            Write-Warning "Username should only contain alphanumeric characters. Please try again."
            continue
        }
        break
    } while ($true)
    
    $dbx_email = "$user_name@medtronic.com"
    $dbx_path = "/Workspace/Users/$dbx_email/$script:REPO_NAME"
    
    # Function to get profile for environment
    function Get-ProfileForEnv {
        param([string]$Environment)
        switch ($Environment) {
            "PROD" { return "prod" }
            "STAGE" { return "stage" }
            "DEV" { return "dev" }
            default { return "dev" }
        }
    }
    
    # Setup repository in DEV environment only
    # Stage and Prod workspace connections will be created automatically on deployment via azure-pipeline-dbx.yml
    $environments = @("DEV")
    $failedEnvs = @()
    
    foreach ($env in $environments) {
        $profile = Get-ProfileForEnv $env
        
        Write-Log "Linking repository in Databricks $env environment with CLI profile '$profile'..."
        
        # Try to create the repository with detailed error handling
        try {
            # Run from home directory to avoid databricks.yml bundle interference
            $currentDir = Get-Location
            Set-Location $env:USERPROFILE
            
            $createOutput = databricks --profile $profile repos create $script:REMOTE_URL azureDevOpsServices --path $dbx_path 2>&1
            $exitCode = $LASTEXITCODE
            
            # Return to original directory
            Set-Location $currentDir
            
            if ($exitCode -eq 0) {
                Write-Success "Successfully linked to Databricks $env at $dbx_path"
            } else {
                # Check if the error is because repository already exists
                if ($createOutput -match "already exists|path.*exists") {
                    Write-Warning "Repository already exists in Databricks $env at $dbx_path"
                } else {
                    Write-Error "Failed to create repository in Databricks $env`: $createOutput"
                    $failedEnvs += $env
                }
            }
        } catch {
            # Ensure we return to original directory
            if ($currentDir) {
                Set-Location $currentDir
            }
            Write-Error "Failed to create repository in Databricks $env`: $_"
            $failedEnvs += $env
        }
    }
    
    # Report results
    if ($failedEnvs.Count -eq 0) {
        Write-Success "Databricks integration completed successfully for all environments"
        return $true
    } else {
        Write-Error "Databricks integration failed for environments: $($failedEnvs -join ', ')"
        Write-Warning "You may need to manually configure these environments or check your permissions"
        return $false
    }
}

# Main script execution
try {
    # Execute Azure DevOps setup
    if (-not (Start-AzureSetup)) {
        Handle-Error "Azure DevOps setup failed" "Main execution"
    }

    # Main integration setup
    Write-Log "=== Repository Integration Setup ==="
    Write-Host ""

    $setupSnowflake = Read-Host "Do you want to link this repo in Snowflake? (y/n)"
    $setupDatabricks = Read-Host "Do you want to link this repo in Databricks? (y/n)"

    # Track integration results
    $snowflakeSuccess = $false
    $databricksSuccess = $false

    if ($setupSnowflake -eq "y" -or $setupSnowflake -eq "Y") {
        if (Set-SnowflakeIntegration) {
            $snowflakeSuccess = $true
        } else {
            Write-Error "Snowflake setup failed, but continuing with other integrations..."
        }
    }

    if ($setupDatabricks -eq "y" -or $setupDatabricks -eq "Y") {
        if (Set-DatabricksIntegration) {
            $databricksSuccess = $true
        } else {
            Write-Error "Databricks setup failed, but continuing..."
        }
    }

    # Final summary
    Write-Host ""
    Write-Log "=== Setup Summary ==="
    Write-Success "Azure DevOps setup completed successfully!"
    Write-Success "Repository: $script:REPO_NAME"
    Write-Success "Remote URL: $script:REMOTE_URL"
    Write-Success "Branches created: dev (default), main, stage"

    Write-Host ""
    Write-Log "Integration Status:"
    if ($setupSnowflake -eq "y" -or $setupSnowflake -eq "Y") {
        if ($snowflakeSuccess) {
            Write-Success "Snowflake integration completed successfully"
        } else {
            Write-Error "Snowflake integration failed"
        }
    }

    if ($setupDatabricks -eq "y" -or $setupDatabricks -eq "Y") {
        if ($databricksSuccess) {
            Write-Success "Databricks integration completed successfully" 
        } else {
            Write-Error "Databricks integration failed"
        }
    }

    # Overall status message
    Write-Host ""
    if (($setupSnowflake -ne "y" -and $setupSnowflake -ne "Y") -and ($setupDatabricks -ne "y" -and $setupDatabricks -ne "Y")) {
        Write-Success "Project setup completed! Your project is ready for development."
    } elseif ((($setupSnowflake -ne "y" -and $setupSnowflake -ne "Y") -or $snowflakeSuccess) -and (($setupDatabricks -ne "y" -and $setupDatabricks -ne "Y") -or $databricksSuccess)) {
        Write-Success "Project setup completed successfully! Your project is ready for development."
    } else {
        Write-Warning "Something went wrong in the setup process. Please have a look at the ERROR messages above."
    }

} catch {
    Handle-Error $_.Exception.Message "Main execution"
}
