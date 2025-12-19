# Data Science Project Template

A standardized cookiecutter template for Data Science projects at Medtronic, designed to enforce best practices and provide a consistent project structure across teams.

## Quick Start

### Prerequisites
- Cookiecutter installed (`pip install cookiecutter==2.6.0`)

### Generate a New Project

```bash
cookiecutter https://dev.azure.com/MedtronicBI/DigIC%20GR%20AI/_git/project-template
```

You'll be prompted to answer several questions that customize your project:

#### Configuration Prompts

| Prompt | Description | Options |
|--------|-------------|---------|
| `project_name` | Human-readable project name | Free text (e.g., "Yoda - Recommended Opportunity") |
| `repo_name` | Repository/folder name | Free text (e.g., "PXXX") |
| `author_name` | Author or organization name | Free text (e.g., "Medtronic") |
| `description` | Brief project description | Free text |
| `project_platform` | Target platform for deployment | `Snowflake` or `Databricks` |
| `python_version` | Python version for the project | Free text (e.g., "3.9", "3.10") |
| `environment_manager` | Python environment management tool | `virtualenv`, `conda`, `pipenv`, `poetry`, `uv`, `none` |
| `dependency_file` | Dependency specification format | `requirements.txt`, `pyproject.toml`, `environment.yml`, `Pipfile` |

## Project Structure

The generated project follows data science best practices with clear separation of concerns:

```
repo_name/
├── data/                          # Data storage (git-ignored)
│   ├── external/                  # External data sources
│   ├── interim/                   # Intermediate processed data
│   ├── processed/                 # Final processed data
│   └── raw/                       # Raw immutable data
├── docs/                          # Project documentation
│   ├── docs/                      # MkDocs documentation source
│   ├── mkdocs.yml                 # MkDocs configuration
│   └── README.md                  # Project-specific README
├── models/                        # Trained models and serialized objects
├── notebooks/                     # Jupyter notebooks
│   ├── shared/                    # Shared notebook utilities
│   └── [dependency_file]          # Environment-specific dependency file
├── references/                    # Data dictionaries, manuals, explanatory materials
├── reports/                       # Generated analysis reports
├── src/                          # Source code for the project
│   └── __init__.py               # Makes src a Python module
├── .env                          # Environment variables (git-ignored)
├── .gitignore                    # Git ignore rules
├── Makefile                      # Automation commands
├── setup.cfg                     # Python package configuration
├── [OS-specific setup script]   # Setup script based on operating_system choice
└── [platform-specific files]    # Files based on platform choice
```

### Platform and OS-Specific Files

The template automatically configures your project based on the selected platform and operating system using **post-generation hooks**. Unwanted platform-specific and OS-specific files are automatically removed during project generation.

#### When `project_platform = "Snowflake"`:
```
├── .snowflake/                   # Snowflake configuration
│   ├── config.toml              # Snowflake connection config
│   ├── deploy.sql               # SQL deployment scripts
│   └── deploy_sql.py            # Python deployment utilities
├── streamlit/                   # Streamlit app directory
│   ├── streamlit_app.py         # Main Streamlit application
│   └── environment.yml          # Streamlit dependencies
└── azure-pipeline-sf.yml        # Azure DevOps CI/CD pipeline template for Snowflake
```
*Note: Databricks-specific files (`azure-pipeline-dbx.yml`, `databricks.yml`) are automatically removed.*

#### When `project_platform = "Databricks"`:
```
├── databricks.yml               # Databricks project configuration for pipeline
└── azure-pipeline-dbx.yml       # Azure DevOps CI/CD pipeline template for Databricks
```
*Note: Snowflake-specific files (`.snowflake/`, `streamlit/`, `azure-pipeline-sf.yml`) are automatically removed.*

#### Setup and Create Scripts
Both Windows and macOS/Linux scripts are included in every generated project:
```
├── setup.ps1                    # Windows PowerShell setup script
├── setup.sh                     # Unix/macOS setup script
├── create.ps1                   # PowerShell script to create notebooks/Streamlit apps
├── create.sh                    # Bash script to create notebooks/Streamlit apps
```

### Dependency Management Files

Based on your `dependency_file` choice, one of the following will be created in the `notebooks/` directory:

- **requirements.txt**: Traditional pip requirements
- **pyproject.toml**: Modern Python packaging with Poetry/UV
- **environment.yml**: Conda environment specification
- **Pipfile**: Pipenv dependency management

## Getting Started with Your New Project

After generating your project:

> **📝 Note**: The template uses post-generation hooks to automatically clean up platform-specific files. You'll see confirmation messages during generation (e.g., "Removed azure-pipeline-sf.yml", "Project template configured for Databricks").

### 1. Setup Scripts (Recommended)

Navigate to your project directory and run the setup script for your operating system:

**Windows:**
```powershell
.\setup.ps1
```

**macOS/Linux:**
```bash
./setup.sh
```

This will:
- Configure Azure DevOps CLI with organization and project defaults
- Prompt for new repository name
- Create new Azure DevOps repository
- Initialize local git repository with initial commit
- Create and push `main`, `stage`, and `dev` branches
- Set up remote origin
- Optionally link repository in Snowflake:
  - Create git repository object with Azure DevOps integration
  - Create project schema in PROD_GR_AI_DB, STAGE_GR_AI_DB, and DEV_GR_AI_DB
  - Grant appropriate permissions to GR_AI_ENGINEER role
- Optionally link repository in Databricks:
  - Create repository links in all three environments (PROD, STAGE, DEV)
  - Set up workspace paths under user directory

**Important**: When you choose to link the repository to Snowflake, you will be prompted to provide a private key passphrase. Here you have to insert the passphrase of the Service Principal. Please ask Ronald to pass it to you.

### 2. Create Scripts - Adding Notebooks and Streamlit Apps

Use the create scripts to add new notebooks and Streamlit applications with automatic git and Snowflake integration.

**For Windows:**
```powershell
.\create.ps1
```

**For macOS/Linux:**
```bash
./create.sh
```

The script will first ask whether you want to:
1. **Create new** - Creates new files and connects them to Azure DevOps + Snowflake
2. **Connect existing** - For files that already exist locally, just connects them to Azure DevOps + Snowflake

This is useful when you've been experimenting with a notebook locally and later decide to integrate it into the CI/CD pipeline.

This will:
- Prompt for create new vs. connect existing choice
- Prompt for notebook/Streamlit app creation choice
- For "Create new": Generate empty Jupyter notebooks (`.ipynb`) or Streamlit app templates
- For "Connect existing": Verify the file exists locally
- Pull latest changes from remote repository
- Add files to git staging and commit with custom message
- Push changes to remote repository
- Authenticate with Snowflake using service principal private key
- Fetch latest git repository state in Snowflake
- Create notebook objects in `DEV_GR_AI_DB.{repo_name}.{notebook_name}`
- Create Streamlit app objects in `DEV_GR_AI_DB.{repo_name}.{streamlit_name}`
- Add live versions to created notebooks

**Important**: You will be prompted to provide your Snowflake private key passphrase. Please ask Ronald to pass it to you.

## Branching Strategy

This template implements a Git branching strategy aligned with the team's deployment pipeline:

- **`main`** - Production branch → `PROD_GR_AI_DB`
- **`stage`** - Staging branch → `STAGE_GR_AI_DB`  
- **`dev`** - Development branch → `DEV_GR_AI_DB`
- **`feature/*`** - Feature branches → `DEV_GR_AI_DB`

## CI/CD Pipeline

The included pipeline file (platform-specific) provides:

- **Triggers**: Pull requests to stage/main and pushes to main/stage/dev
- **Environment-specific database mapping** via Azure DevOps variables
- **Platform-specific authentication**:
  - **Snowflake**: JWT authentication via private key
  - **Databricks**: Token-based authentication
- **Connection testing** and validation
- **Notebook structure validation**

### Snowpark Container Services (Snowflake only)

The Snowflake pipeline supports deploying Streamlit apps as containerized services. To use this feature:

1. Create a subfolder under `streamlit/` for your app (e.g., `streamlit/myapp/`)
2. Add your `streamlit_app.py` to the subfolder
3. Add a `Dockerfile` to the same subfolder
4. (Optional) Add an `environment.yml` for Conda dependencies

The pipeline will automatically:
- Detect the Dockerfile and build a Docker image
- Push the image to Snowflake's image registry
- Create a Snowpark Container Service instead of a native Streamlit app

You can mix containerized and native Streamlit apps in the same project - apps without a Dockerfile will be deployed as native Streamlit apps.

## Best Practices

### Data Management
- Store raw data in `data/raw/` (immutable)
- Process data through `data/interim/` to `data/processed/`
- Never commit data files to git (handled by `.gitignore`)

### Code Organization
- Keep reusable code in `src/`
- Use notebooks for exploration and reporting
- Maintain shared utilities in `notebooks/shared/`

### Documentation
- Update project README in `docs/README.md`
- Use MkDocs for comprehensive documentation
- Document data schemas in `references/`

### Version Control
- Follow the branching strategy
- Use meaningful commit messages
- Create pull requests for code reviews
