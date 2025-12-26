# uvm Usage Examples

This document provides practical examples for common uvm usage scenarios.

## Table of Contents

- [Basic Workflow](#basic-workflow)
- [Project-Specific Environments](#project-specific-environments)
- [Multiple Python Versions](#multiple-python-versions)
- [Shared Environments](#shared-environments)
- [Migration from Conda](#migration-from-conda)

---

## Basic Workflow

### Creating Your First Environment

```bash
# Create an environment with the default Python version
uvm create myenv

# Create with a specific Python version
uvm create data-science --python 3.11
```

### Installing Packages

```bash
# Activate the environment
uvm activate data-science

# Install packages using pip (UV accelerated)
pip install numpy pandas matplotlib scikit-learn

# Or use uv directly for even faster installation
uv pip install numpy pandas matplotlib scikit-learn

# Verify installation
python -c "import pandas; print(pandas.__version__)"
```

### Listing and Managing Environments

```bash
# List all environments
uvm list

# Output example:
#   data-science              Python 3.11.5      /home/user/uv_envs/data-science
# * myenv                     Python 3.12.0      /home/user/uv_envs/myenv

# Delete an environment
uvm delete myenv
```

---

## Project-Specific Environments

### Scenario 1: Modern Project with pyproject.toml

```bash
# Navigate to your project
cd ~/projects/my-fastapi-app

# Create a local .venv
uv venv

# Install dependencies
uv pip install -r requirements.txt
# or
uv sync  # if using pyproject.toml

# The environment auto-activates when you cd into the directory
cd ~/projects/my-fastapi-app
# 🔄 Auto-activating local .venv

# Run your application
python main.py

# Leave the directory
cd ~
# 🔻 Deactivating environment (left project directory)
```

### Scenario 2: Legacy Project with requirements.txt

```bash
# Create a shared environment
uvm create legacy-app --python 3.9

# Navigate to your project
cd ~/projects/legacy-app

# Link the environment using .uvmrc
echo "legacy-app" > .uvmrc

# Install dependencies
pip install -r requirements.txt

# The environment auto-activates
cd ~/projects/legacy-app
# 🔄 Auto-activating uvm environment: legacy-app
```

---

## Multiple Python Versions

### Testing Across Python Versions

```bash
# Create environments for different Python versions
uvm create py38 --python 3.8
uvm create py39 --python 3.9
uvm create py310 --python 3.10
uvm create py311 --python 3.11
uvm create py312 --python 3.12

# Test your package in Python 3.8
uvm activate py38
python -m pytest tests/

# Test in Python 3.11
uvm deactivate
uvm activate py311
python -m pytest tests/

# List all test environments
uvm list
```

### Development vs Production Environments

```bash
# Development environment with latest Python
uvm create dev --python 3.12
uvm activate dev
pip install -r requirements-dev.txt  # includes pytest, black, mypy

# Production environment with stable Python
uvm create prod --python 3.11
uvm activate prod
pip install -r requirements.txt  # only production dependencies
```

---

## Shared Environments

### Scenario: Multiple Projects Sharing Dependencies

```bash
# Create a shared data science environment
uvm create ds-common --python 3.11
uvm activate ds-common
pip install numpy pandas matplotlib scikit-learn jupyter

# Project 1: Sales Analysis
cd ~/projects/sales-analysis
echo "ds-common" > .uvmrc
# Auto-activates ds-common when entering

# Project 2: Customer Segmentation
cd ~/projects/customer-segmentation
echo "ds-common" > .uvmrc
# Auto-activates ds-common when entering

# Both projects share the same environment
```

### Scenario: Learning Environment

```bash
# Create a learning environment
uvm create learning --python 3.11
uvm activate learning

# Install common learning packages
pip install requests beautifulsoup4 flask django

# Create multiple learning projects
mkdir -p ~/learning/web-scraping
cd ~/learning/web-scraping
echo "learning" > .uvmrc

mkdir -p ~/learning/flask-tutorial
cd ~/learning/flask-tutorial
echo "learning" > .uvmrc

# All learning projects use the same environment
```

---

## Migration from Conda

### Conda to uvm Command Mapping

| Conda Command | uvm Equivalent | Notes |
|---------------|----------------|-------|
| `conda create -n myenv python=3.11` | `uvm create myenv --python 3.11` | ✅ |
| `conda activate myenv` | `uvm activate myenv` | Requires shell-hook |
| `conda deactivate` | `uvm deactivate` | Requires shell-hook |
| `conda env list` | `uvm list` | ✅ |
| `conda remove -n myenv --all` | `uvm delete myenv` | ✅ |
| `conda install package` | `pip install package` | Use pip/uv pip |
| `conda env export` | `pip freeze > requirements.txt` | Manual export |

### Migration Example

**Before (Conda):**

```bash
# Create environment
conda create -n myproject python=3.11

# Activate
conda activate myproject

# Install packages
conda install numpy pandas matplotlib

# Deactivate
conda deactivate
```

**After (uvm):**

```bash
# Create environment
uvm create myproject --python 3.11

# Activate (after enabling shell-hook)
uvm activate myproject

# Install packages (faster with UV)
pip install numpy pandas matplotlib
# or
uv pip install numpy pandas matplotlib

# Deactivate
uvm deactivate
```

### Exporting Conda Environment to uvm

```bash
# In your conda environment
conda activate myenv
pip freeze > requirements.txt
conda deactivate

# Create equivalent uvm environment
uvm create myenv --python 3.11
uvm activate myenv
pip install -r requirements.txt
```

---

## Advanced Patterns

### Temporary Testing Environment

```bash
# Create a temporary environment
uvm create temp-test --python 3.11

# Activate and test
uvm activate temp-test
pip install some-experimental-package
python test_script.py

# Clean up
uvm deactivate
uvm delete temp-test --force
```

### Custom Environment Location

```bash
# Create environment on external drive
uvm create bigdata --python 3.11 --path /mnt/external/envs/bigdata

# Still managed by uvm
uvm list  # Shows custom path
uvm activate bigdata  # Works normally
```

### Quick Package Testing

```bash
# Create, activate, test, and delete in one session
uvm create test-pkg --python 3.11
uvm activate test-pkg
pip install new-package
python -c "import new_package; print(new_package.__version__)"
uvm deactivate
uvm delete test-pkg --force
```

---

## Tips and Best Practices

### 1. Use Local `.venv` for Projects

For modern projects with `pyproject.toml`, prefer local `.venv`:

```bash
cd ~/projects/myapp
uv venv
uv sync
# Auto-activates, no .uvmrc needed
```

### 2. Use Shared Environments for Learning

For learning and experimentation, use shared environments:

```bash
uvm create learning --python 3.11
# Reuse across multiple learning projects
```

### 3. Pin Python Versions in Production

Always specify Python version for production environments:

```bash
uvm create prod-api --python 3.11.5  # Pin exact version
```

### 4. Use `uv pip` for Faster Installation

```bash
uvm activate myenv
uv pip install -r requirements.txt  # Much faster than pip
```

### 5. Regular Cleanup

```bash
# List all environments
uvm list

# Delete unused environments
uvm delete old-project --force
uvm delete temp-env --force
```

---

## Troubleshooting Examples

### Problem: Environment Not Auto-Activating

**Solution:**

```bash
# 1. Check if shell-hook is enabled
grep "uvm shell-hook" ~/.bashrc

# 2. If not found, add it
echo 'eval "$(uvm shell-hook)"' >> ~/.bashrc
source ~/.bashrc

# 3. Test
cd ~/projects/myapp
# Should see: 🔄 Auto-activating...
```

### Problem: Wrong Environment Activated

**Solution:**

```bash
# Check current directory for .venv or .uvmrc
ls -la | grep -E "\.venv|\.uvmrc"

# .venv takes priority over .uvmrc
# Remove .uvmrc if you want to use .venv
rm .uvmrc
```

### Problem: Slow Package Installation

**Solution:**

```bash
# Verify mirrors are configured
cat ~/.config/uv/uv.toml

# Should show Tsinghua mirrors
# If not, reconfigure
uvm config mirror

# Use uv pip instead of pip
uv pip install package  # Much faster
```

---

## Real-World Workflows

### Web Development

```bash
# Backend API
cd ~/projects/backend-api
uv venv
uv pip install fastapi uvicorn sqlalchemy

# Frontend (if using Python tools)
cd ~/projects/frontend
echo "backend-api" > .uvmrc  # Share backend environment
```

### Data Science

```bash
# Create DS environment
uvm create ds --python 3.11
uvm activate ds
uv pip install numpy pandas matplotlib seaborn jupyter scikit-learn

# Use in multiple notebooks
cd ~/notebooks/analysis1
echo "ds" > .uvmrc

cd ~/notebooks/analysis2
echo "ds" > .uvmrc
```

### Testing and CI/CD

```bash
# Create test environments
uvm create test-py38 --python 3.8
uvm create test-py311 --python 3.11
uvm create test-py312 --python 3.12

# Run tests in each
for env in test-py38 test-py311 test-py312; do
    uvm activate $env
    pytest tests/
    uvm deactivate
done
```

---

For more information, see the main [README.md](README.md).

