.PHONY: setup-all git-init git-remote branches feature-branch

setup-all: git-init git-remote branches
	@echo "Setup complete! You can now create feature branches as needed."

git-init:
	git init
	git add .
	git commit -m "Initial commit: project template"
	git branch -M main

git-remote:
	@if [ -z "$$REPO_URL" ]; then \
		read -p "Enter Azure DevOps repository URL (from Clone button): " REPO_URL; \
	fi; \
	if git remote | grep -q origin; then \
		git remote set-url origin $$REPO_URL; \
	else \
		git remote add origin $$REPO_URL; \
	fi; \
	git push -u origin main

branches:
	if ! git show-ref --quiet refs/heads/stage; then \
		git checkout -b stage; \
		git push -u origin stage; \
	fi; \
	git checkout main; \
	if ! git show-ref --quiet refs/heads/dev; then \
		git checkout -b dev; \
		git push -u origin dev; \
	fi; \
	git checkout main

feature-branch:
	@if [ -z "$(NAME)" ]; then \
		read -p "Enter feature branch name (e.g. new-feature): " NAME; \
	fi; \
	git checkout dev; \
	git pull origin dev; \
	git checkout -b feature/$$NAME; \
	git push -u origin feature/$$NAME
