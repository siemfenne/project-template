# Data Science Project Template

A standardized cookiecutter template for Data Science projects at Medtronic, designed to enforce best practices and provide a consistent project structure across teams.

## 🚀 Quick Start

### Prerequisites
- Python 3.7+ installed
- Cookiecutter installed (`pip install cookiecutter`)
- Azure CLI installed and configured (for automatic repository creation)
- Git installed

### Generate a New Project

```bash
cookiecutter https://dev.azure.com/MedtronicBI/DigIC%20GR%20AI/_git/project-template
```

You'll be prompted to answer several questions that customize your project:

#### Configuration Prompts

| Prompt | Description | Options |
|--------|-------------|---------|
| `project_name` | Human-readable project name | Free text (e.g., "Customer Analytics Pipeline") |
| `repo_name` | Repository/folder name | Free text (e.g., "customer-analytics-pipeline") |
| `author_name` | Author or organization name | Free text (e.g., "Data Science Team") |
| `description` | Brief project description | Free text |
| `project_platform` | Target platform for deployment | `Snowflake` or `Databricks` |
| `environment_manager` | Python environment management tool | `virtualenv`, `conda`, `pipenv`, `uv`, `none` |
| `dependency_file` | Dependency specification format | `requirements.txt`, `pyproject.toml`, `environment.yml`, `Pipfile` |

## 📁 Project Structure

The generated project follows data science best practices with clear separation of concerns:

```
your-project/
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
├── azure-pipeline.yml            # Azure DevOps CI/CD pipeline
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
    └── requirements.txt         # Streamlit dependencies
```

#### When `project_platform = "Databricks"`:
```
└── databricks.yml               # Databricks project configuration
```

### Dependency Management Files

Based on your `dependency_file` choice, one of the following will be created in the `notebooks/` directory:

- **requirements.txt**: Traditional pip requirements
- **pyproject.toml**: Modern Python packaging with Poetry/UV
- **environment.yml**: Conda environment specification
- **Pipfile**: Pipenv dependency management

## 🛠️ Getting Started with Your New Project

After generating your project:

### 1. Initial Setup

Navigate to your project directory and run the appropriate setup script:

**Windows (PowerShell):**
```powershell
.\setup.ps1
```

**Unix/Linux/macOS:**
```bash
./setup.sh
```

### 2. Initialize Repository (Optional)

Use the Makefile to automatically create an Azure DevOps repository and set up branching:

```bash
make init-repo
```

This will:
- Create a new Azure DevOps repository
- Initialize git with initial commit
- Create and push `main`, `stage`, and `dev` branches
- Set up remote origin

### 3. Environment Setup

Depending on your chosen environment manager:

**UV (Recommended):**
```bash
make env-uv
```

**Conda:**
```bash
make env-conda
```

**Virtualenv:**
```bash
make env-venv
```

**Pipenv:**
```bash
make env-pipenv
```

### 4. Available Make Commands

| Command | Description |
|---------|-------------|
| `make test` | Run basic project tests |
| `make init-repo` | Create Azure DevOps repo and initialize git |
| `make full` | Complete project setup |
| `make snowflake` | Snowflake-specific setup |
| `make databricks` | Databricks-specific setup |
| `make feature-branch` | Create a new feature branch |

## 🔀 Branching Strategy

This template implements a Git branching strategy aligned with the team's deployment pipeline:

- **`main`** - Production branch → `PROD_GR_AI_DB`
- **`stage`** - Staging branch → `STAGE_GR_AI_DB`  
- **`dev`** - Development branch → `DEV_GR_AI_DB`
- **`feature/*`** - Feature branches → `DEV_GR_AI_DB`

## 🚦 CI/CD Pipeline

The included `azure-pipeline.yml` provides:

- **Triggers**: Pull requests to stage/main and pushes to main/stage/dev
- **Environment-specific database mapping** via Azure DevOps variables
- **Snowflake CLI authentication** via JWT (private key)
- **Connection testing** for both temporary and named connections
- **Notebook structure validation**

### Required Azure DevOps Secrets

Ensure these secrets are configured in your Azure DevOps project:

- `SNOWFLAKE_ACCOUNT`
- `SNOWFLAKE_USER`  
- `SNOWFLAKE_PRIVATE_KEY_RAW`
- `SNOWFLAKE_PASSPHRASE` (optional if key is encrypted)

## 📝 Best Practices

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

## 🤝 Support

For questions or issues with this template:

1. Check the existing documentation in `docs/`
2. Review the Makefile for available commands
3. Contact the DevOps team for template updates

---

*This template is part of the Data Science development maturity initiative to standardize project structures and deployment practices across Medtronic Data Science teams.*
