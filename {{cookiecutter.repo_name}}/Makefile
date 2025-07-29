.PHONY: all init-repo snowflake databricks full feature-branch test

# Set variables - override via command line or export
ORG_URL ?= https://dev.azure.com/MedtronicBI
PROJECT ?= DigIC%20GR%20AI

test:
	@echo "Test passed!"

# Main entry point: interactive project initialization
all: full

# 1. Create new Azure DevOps repo and push initial commit
init-repo:
	@echo "Enter new repository name:"
	@read repo_name; \
	echo "Using repo name: $$repo_name"; \
	az devops configure --defaults organization=$(ORG_URL) project=$(PROJECT); \
	az repos create --name $$repo_name; \
	remote_url="$(ORG_URL)/$(PROJECT)/_git/$$repo_name"; \
	git init; \
	git add .; \
	git commit -m 'Initial commit: project template'; \
	git branch -M main; \
	git remote add origin $$remote_url; \
	git push -u origin main; \
	[ "$$(git branch --list stage)" ] || { git checkout -b stage && git push -u origin stage; }; \
	git checkout main; \
	[ "$$(git branch --list dev)" ] || { git checkout -b dev && git push -u origin dev; }; \
	git checkout main; \
	echo "Setup complete! Repo '$$repo_name' created, branches ready."

# 2. Link repo to Snowflake (interactive)
snowflake:
	@echo "Enter repository name for Snowflake (should match repo):"
	@read repo_name; \
	echo "Linking to Snowflake for repo: $$repo_name"; \
	echo "Enter remote URL (should match Azure DevOps remote):"; \
	read remote_url; \
	read -s -p "Enter private key passphrase: " passphrase; \
	echo; \
	export PRIVATE_KEY_PASSPHRASE=$$passphrase; \
	sf_cmd="CREATE GIT REPOSITORY IF NOT EXISTS $$repo_name \
	ORIGIN = '$$remote_url' \
	API_INTEGRATION = API_GR_GIT_AZURE_DEVOPS \
	GIT_CREDENTIALS = EMEA_UTILITY_DB.SECRETS.SECRET_GR_GIT_AZURE_DEVOPS;"; \
	echo "Creating Git repo object in Snowflake..."; \
	snow sql -c service_principal -q "$$sf_cmd"; \
	for db in PROD_GR_AI_DB STAGE_GR_AI_DB DEV_GR_AI_DB; do \
		sql="USE DATABASE $$db; CREATE SCHEMA IF NOT EXISTS $$repo_name; GRANT ALL PRIVILEGES ON SCHEMA $$repo_name TO ROLE GR_AI_ENGINEER;"; \
		echo "Initializing schema and grants in $$db..."; \
		snow sql -c service_principal -q "$$sql"; \
	done; \
	unset PRIVATE_KEY_PASSPHRASE

# 3. Link repo to Databricks (interactive)
databricks:
	@echo "Enter repository name for Databricks (should match repo):"
	@read repo_name; \
	echo "Enter Azure DevOps remote URL:"; \
	read remote_url; \
	echo "Enter your Medtronic username (e.g., fennes2):"; \
	read user_name; \
	dbx_email="$$user_name@medtronic.com"; \
	dbx_path="/Workspace/Users/$$dbx_email/$$repo_name"; \
	for env in PROD STAGE DEV; do \
		case $$env in \
			PROD) profile="prod"; url="https://medtronic-ml-globalregionsit-prod.cloud.databricks.com";; \
			STAGE) profile="stage"; url="https://medtronic-ml-globalregionsit-stage.cloud.databricks.com";; \
			DEV) profile="dev"; url="https://medtronic-ml-globalregionsit-dev.cloud.databricks.com";; \
		esac; \
		echo "Linking repo in Databricks $$env..."; \
		databricks --profile $$profile repos create $$remote_url azureDevOpsServices --path $$dbx_path || \
		echo "Repo may already exist or an error occurred in Databricks $$env."; \
	done

# 4. Full workflow, with user prompts for which integrations to run
full:
	@echo "Project Initialization Wizard"
	@echo "----------------------------"
	@echo "Step 1: Create Azure DevOps Repo"
	@$(MAKE) init-repo
	@echo
	@read -p "Do you want to link this repo in Snowflake? (y/n): " snow; \
	if [ "$$snow" = "y" ]; then \
		$(MAKE) snowflake; \
	fi
	@echo
	@read -p "Do you want to link this repo in Databricks? (y/n): " dbx; \
	if [ "$$dbx" = "y" ]; then \
		$(MAKE) databricks; \
	fi
	@echo "All done! Project ready, integrations completed if chosen."

feature-branch:
	@echo "Enter short description for your feature branch (no spaces):"
	@read desc; \
	branch="feature/$$desc"; \
	echo "Switching to dev branch..."; \
	git checkout dev; \
	git pull origin dev; \
	echo "Creating new branch: $$branch"; \
	git checkout -b $$branch; \
	git push -u origin $$branch; \
	echo "Feature branch '$$branch' created and pushed."