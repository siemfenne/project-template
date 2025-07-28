# Set your Azure DevOps org and project
$organization = "https://dev.azure.com/MedtronicBI"
$project = "DigIC GR AI"

# Login (uses cached credentials, or set a PAT env var)
az devops configure --defaults organization=$organization project=$project

# Prompt for new repo name
$repo_name = Read-Host "Enter new repository name"

# Create the new repository in Azure DevOps
az repos create --name $repo_name

# URL encode the project name (replace spaces with %20)
$remote_project = $project -replace ' ', '%20'

# Build the correct remote URL
$remote_url = "$organization/$remote_project/_git/$repo_name"

# Initialize local git and first commit
git init
git add .
git commit -m "Initial commit: project template"
git branch -M main

# Add remote and push
git remote add origin $remote_url
git push -u origin main

# Create and push stage branch if not exists
if (-not (git branch --list stage)) {
    git checkout -b stage
    git push -u origin stage
}
git checkout main

# Create and push dev branch if not exists
if (-not (git branch --list dev)) {
    git checkout -b dev
    git push -u origin dev
}
git checkout main

Write-Host "Setup complete! Repo '$repo_name' created in Azure DevOps, branches ready."

$setupSnowflake = Read-Host "Do you want to link this repo in Snowflake? (y/n)"
$setupDatabricks = Read-Host "Do you want to link this repo in Databricks? (y/n)"

if ($setupSnowflake -eq "y") {
    # Prompt for Snowflake passphrase (set env var for this session)
    $passphrase = Read-Host -AsSecureString "Enter private key passphrase"
    $unsecurePass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($passphrase))
    $env:PRIVATE_KEY_PASSPHRASE = $unsecurePass

    $sf_cmd = @"
CREATE GIT REPOSITORY IF NOT EXISTS $repo_name
  ORIGIN = '$remote_url'
  API_INTEGRATION = API_GR_GIT_AZURE_DEVOPS
  GIT_CREDENTIALS = EMEA_UTILITY_DB.SECRETS.SECRET_GR_GIT_AZURE_DEVOPS;
"@

    Write-Host "Creating Git repository object in Snowflake..."
    snow sql -c service_principal -q $sf_cmd

    $databases = @("PROD_GR_AI_DB", "STAGE_GR_AI_DB", "DEV_GR_AI_DB")
    $role = "GR_AI_ENGINEER"

    Write-Host "Creating schemas and assigning grants in each environment database..."
    foreach ($db in $databases) {
        $sql = @"
USE DATABASE $db;
CREATE SCHEMA IF NOT EXISTS $repo_name;
GRANT ALL PRIVILEGES ON SCHEMA $repo_name TO ROLE $role;
"@
        Write-Host "Initializing schema and grants in $db..."
        snow sql -c service_principal -q $sql
    }

    Remove-Item Env:PRIVATE_KEY_PASSPHRASE
}

if ($setupDatabricks -eq "y") {

    $user_name = Read-Host "Enter your Medtronic username (e.g., fennes2 for Siem Fenne)"
    $dbx_email = "$user_name@medtronic.com"
    $dbx_path = "/Workspace/Users/$dbx_email/$repo_name"

    # List of environments and their respective Databricks profiles and URLs
    $dbx_envs = @(
        @{ Name = "PROD"; Profile = "prod"; URL = "https://medtronic-ml-globalregionsit-prod.cloud.databricks.com" },
        @{ Name = "STAGE"; Profile = "stage"; URL = "https://medtronic-ml-globalregionsit-stage.cloud.databricks.com" },
        @{ Name = "DEV"; Profile = "dev"; URL = "https://medtronic-ml-globalregionsit-dev.cloud.databricks.com" }
    )

    foreach ($env in $dbx_envs) {
        Write-Host "Linking repo in Databricks $($env.Name) environment..."

        # Try to create the repo
        try {
            databricks --profile $($env.Profile) repos create $remote_url azureDevOpsServices --path $dbx_path
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully linked to Databricks $($env.Name) at $dbx_path"
            } else {
                Write-Host "Could not create repo in Databricks $($env.Name). It may already exist or there was an error."
            }
        } catch {
            Write-Host "Exception occurred creating Databricks repo in $($env.Name): $_"
        }
    }

    Write-Host "Databricks integration complete."
}

Write-Host "All done! Project ready, and integrations completed if chosen."


