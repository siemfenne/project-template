# setup.ps1

git init
git add .
git commit -m "Initial commit: project template"
git branch -M main
$repo_url = Read-Host "Enter Azure DevOps repository URL (from browser address bar)"
git remote add origin $repo_url
git push -u origin main
git checkout -b stage
git push -u origin stage
git checkout main
git checkout -b dev
git push -u origin dev
git checkout main
Write-Host "Setup complete! You can now create feature branches as needed."
