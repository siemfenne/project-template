# Project Template

A cookiecutter template for Python projects with Docker containerization, Google Cloud hosting, and GitHub integration.

## Quick Start

### Prerequisites
- [Cookiecutter](https://cookiecutter.readthedocs.io/) installed (`pip install cookiecutter==2.6.0`)
- [GitHub CLI](https://cli.github.com/) installed and authenticated (`gh auth login`)

### Generate a New Project

```bash
cookiecutter [https://github.com/siemfenne/project-template](https://github.com/siemfenne/project-template)
```

You'll be prompted to answer several questions that customize your project:

#### Configuration Prompts

| Prompt | Description | Options |
|--------|-------------|---------|
| `project_name` | Human-readable project name | Free text |
| `repo_name` | Repository/folder name | Free text |
| `author_name` | Author or organization name | Free text |
| `description` | Brief project description | Free text |
| `project_management` | Platform for project management and CI/CD | `Github` or `Azure DevOps` |
| `python_version` | Python version for the project | Free text (e.g., "3.11", "3.12") |
| `environment_manager` | Python environment management tool | `virtualenv`, `conda`, `pipenv`, `poetry`, `uv`, `none` |
| `dependency_file` | Dependency specification format | `requirements.txt`, `pyproject.toml`, `environment.yml`, `Pipfile` |
| `include_dockerfile` | Include Docker and Google Cloud files | `Yes` or `No` |

## Project Structure

The generated project follows best practices with clear separation of concerns:

```
repo_name/
├── .github/                       # GitHub Actions workflows (if Github selected)
│   └── workflows/
│       └── deploy.yml             # CI/CD deployment workflow
├── docs/                          # Project documentation
│   ├── docs/                      # MkDocs documentation source
│   ├── mkdocs.yml                 # MkDocs configuration
│   └── README.md                  # Project-specific README
├── models/                        # Trained models and serialized objects
├── notebooks/                     # Jupyter notebooks and dependency files
├── references/                    # Data dictionaries, manuals, explanatory materials
├── reports/                       # Generated analysis reports
├── src/                           # Application source code
│   ├── main.py                    # Main application entry point
├── .gitignore                     # Git ignore rules
├── setup.sh                       # Setup script to connect project to GitHub
├── Dockerfile                     # Docker container definition (if included)
├── .dockerignore                  # Docker build ignore rules (if included)
├── .gcloudignore                  # Google Cloud deploy ignore rules (if included)
└── azure-pipeline.yml             # Azure DevOps pipeline (if Azure DevOps selected)
```

### Conditional Files

The template uses **post-generation hooks** to automatically remove files that don't match your configuration:

#### When `project_management = "Github"`:
- `azure-pipeline.yml` is removed
- `.github/workflows/deploy.yml` is kept for GitHub Actions CI/CD

#### When `project_management = "Azure DevOps"`:
- `.github/` directory is removed
- `azure-pipeline.yml` is kept for Azure Pipelines CI/CD

#### When `include_dockerfile = "No"`:
- `Dockerfile`, `.dockerignore`, and `.gcloudignore` are removed

### Dependency Management Files

Based on your `dependency_file` choice, one of the following will be created in the `notebooks/` directory:

- **requirements.txt**: Traditional pip requirements
- **pyproject.toml**: Modern Python packaging with Poetry/UV
- **environment.yml**: Conda environment specification
- **Pipfile**: Pipenv dependency management

## Getting Started with Your New Project

After generating your project:

> **Note**: The template uses post-generation hooks to automatically clean up files based on your choices. You'll see confirmation messages during generation.

### 1. Run the Setup Script

Navigate to your generated project directory and run:

```bash
./setup.sh
```

This will:
- Validate that the GitHub CLI (`gh`) is installed and authenticated
- Prompt whether the repository should be **private** or **public**
- Prompt for a repository name (defaults to current directory name)
- Initialize a local git repository with an initial commit
- Create the GitHub repository and push the code
- Create and push a `dev` branch alongside `main`

### 2. Start Developing

After setup, your project is connected to GitHub with two branches:

- **`main`** — Production branch
- **`dev`** — Development branch
- **`feature/*`** — Create feature branches off `dev` for new work

### 3. Docker & Google Cloud (if included)

If you chose `include_dockerfile = "Yes"`, your project includes:

- **`Dockerfile`** — Define your container image for the application in `src/`
- **`.dockerignore`** — Exclude unnecessary files from Docker builds
- **`.gcloudignore`** — Exclude unnecessary files from Google Cloud deployments

## Branching Strategy

- **`main`** — Production-ready code
- **`dev`** — Active development
- **`feature/*`** — Feature branches created from `dev`

## Best Practices

### Code Organization
- Keep application code in `src/`
- Use notebooks for exploration, analysis, and prototyping
- Store trained models in `models/`

### Documentation
- Update project README in `docs/README.md`
- Use MkDocs for comprehensive documentation
- Document data schemas in `references/`

### Version Control
- Follow the branching strategy
- Use meaningful commit messages
- Create pull requests for code reviews
