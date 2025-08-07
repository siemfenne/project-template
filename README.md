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
| `environment_manager` | Python environment management tool | `virtualenv`, `conda`, `pipenv`, `uv`, `none` |
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
├── setup.ps1                    # Windows setup script
├── setup.sh                     # Unix setup script
└── [platform-specific files]    # Files based on platform choice
```

### Platform-Specific Files

#### When `project_platform = "Snowflake"`:
```
├── .snowflake/                   # Snowflake configuration
│   ├── config.toml              # Snowflake connection config
│   ├── deploy.sql               # SQL deployment scripts
│   └── deploy_sql.py            # Python deployment utilities
└── streamlit/                   # Streamlit app directory
    ├── streamlit_app.py         # Main Streamlit application
    └── environment.yml          # Streamlit dependencies
├── azure-pipeline-sf.yml        # Azure DevOps CI/CD pipeline template for Snowflake
```

#### When `project_platform = "Databricks"`:
```
├── databricks.yml               # Databricks project configuration for pipeline
├── azure-pipeline-dbx.yml       # Azure DevOps CI/CD pipeline template for Databricks
```

### Dependency Management Files

Based on your `dependency_file` choice, one of the following will be created in the `notebooks/` directory:

- **requirements.txt**: Traditional pip requirements
- **pyproject.toml**: Modern Python packaging with Poetry/UV
- **environment.yml**: Conda environment specification
- **Pipfile**: Pipenv dependency management

## Getting Started with Your New Project

After generating your project:

### 1. Setup Scripts (Recommended)

Navigate to your project directory and run the appropriate setup script:

**Windows (PowerShell):**
```powershell
.\setup.ps1
```

**Unix/Linux/macOS:**
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

### 2. Using Makefile (Alternative)

Alternatively, use the Makefile to automatically create an Azure DevOps repository and set up branching:

```bash
make init-repo
```

This will:
- Create a new Azure DevOps repository
- Initialize git with initial commit
- Create and push `main`, `stage`, and `dev` branches
- Set up remote origin

### 3. Available Make Commands

| Command | Description |
|---------|-------------|
| `make test` | Run basic project tests |
| `make init-repo` | Create Azure DevOps repo and initialize git |
| `make full` | Complete project setup |
| `make snowflake` | Snowflake-specific setup |
| `make databricks` | Databricks-specific setup |
| `make feature-branch` | Create a new feature branch |

## Branching Strategy

This template implements a Git branching strategy aligned with the team's deployment pipeline:

- **`main`** - Production branch → `PROD_GR_AI_DB`
- **`stage`** - Staging branch → `STAGE_GR_AI_DB`  
- **`dev`** - Development branch → `DEV_GR_AI_DB`
- **`feature/*`** - Feature branches → `DEV_GR_AI_DB`

## CI/CD Pipeline

The included `azure-pipeline.yml` provides:

- **Triggers**: Pull requests to stage/main and pushes to main/stage/dev
- **Environment-specific database mapping** via Azure DevOps variables
- **Snowflake CLI authentication** via JWT (private key)
- **Connection testing** for both temporary and named connections
- **Notebook structure validation**

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
