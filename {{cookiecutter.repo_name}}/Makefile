.PHONY: help git-init git-remote branches feature-branch

help:
	@echo "Usage:"
	@echo "  make git-init      # Initialize git and make initial commit"
	@echo "  make git-remote    # Set up remote (needs REPO_URL, see instructions)"
	@echo "  make branches      # Create dev and stage branches"
	@echo "  make feature-branch NAME=<desc> # Create feature branch from dev"

git-init:
	git init
	git add .
	git commit -m "Initial commit: project template"
	git branch -M main

git-remote:
	@if [ -z "$$REPO_URL" ]; then \
		read -p "Enter Azure DevOps repository URL: " REPO_URL; \
		git remote add origin $$REPO_URL; \
	else \
		git remote add origin $$REPO_URL; \
	fi
	git push -u origin main

branches:
	git checkout -b stage
	git push -u origin stage
	git checkout main
	git checkout -b dev
	git push -u origin dev
	git checkout main

feature-branch:
	@if [ -z "$(NAME)" ]; then \
		read -p "Enter feature branch name (e.g. new-feature): " NAME; \
	fi; \
	git checkout dev; \
	git pull origin dev; \
	git checkout -b feature/$$NAME; \
	git push -u origin feature/$$NAME
