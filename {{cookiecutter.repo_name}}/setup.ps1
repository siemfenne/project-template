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
