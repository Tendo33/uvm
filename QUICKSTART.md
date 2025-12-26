# uvm Quick Start Guide

Get started with uvm in 5 minutes!

## 🚀 Installation (2 minutes)

### Linux / macOS

```bash
# Clone the repository
git clone https://github.com/yourusername/uvm.git
cd uvm

# Run the interactive installer
./install.sh
```

**Follow the wizard:**
- **Step 1/3**: Environment directory (default: ~/uv_envs, press Enter or type custom path)
- **Step 2/3**: Install UV if needed (auto-detected)
- **Step 3/3**: Enable auto-activation? (default: Yes)

```bash
# Reload your shell
source ~/.bashrc  # or ~/.zshrc
```

### Windows (Git Bash)

```bash
# 1. Install UV in PowerShell first
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# 2. Run the interactive installer in Git Bash
git clone https://github.com/yourusername/uvm.git
cd uvm
./install.sh

# 3. Reload your shell
source ~/.bashrc
```

### Quick Install (Skip Wizard)

```bash
# Use defaults for everything
./install.sh -y
```

## 🎯 Enable Auto-Activation (30 seconds)

```bash
# Add shell integration to your ~/.bashrc or ~/.zshrc
echo 'eval "$(uvm shell-hook)"' >> ~/.bashrc
source ~/.bashrc
```

## 📦 Create Your First Environment (1 minute)

```bash
# Create an environment with Python 3.11
uvm create myenv --python 3.11

# Activate it
uvm activate myenv

# Install some packages
pip install requests numpy pandas

# Verify
python -c "import pandas; print('✓ pandas installed')"
```

## 🔄 Try Auto-Activation (2 minutes)

### Option 1: Local Project Environment

```bash
# Create a new project
mkdir ~/my-project
cd ~/my-project

# Create a local .venv
uv venv
uv pip install requests

# Leave and re-enter - watch it auto-activate!
cd ~
cd ~/my-project
# 🔄 Auto-activating local .venv
```

### Option 2: Shared Environment

```bash
# Create a shared environment
uvm create shared-env --python 3.11

# Create a project that uses it
mkdir ~/another-project
cd ~/another-project
echo "shared-env" > .uvmrc

# Enter the directory - auto-activates!
cd ~/another-project
# 🔄 Auto-activating uvm environment: shared-env
```

## 🎉 You're Ready!

Common commands:

```bash
uvm list          # List all environments
uvm activate env  # Activate an environment
uvm deactivate    # Deactivate current environment
uvm delete env    # Delete an environment
uvm help          # Show help
```

## 📚 Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Check out [EXAMPLES.md](EXAMPLES.md) for real-world usage scenarios
- Configure custom settings with `uvm config`

## 🗑️ Uninstall

If you need to remove UVM:

```bash
cd /path/to/uvm
./uninstall.sh
```

**What happens:**
- ✅ Removes UVM files
- ✅ Cleans shell integration  
- ✅ Keeps your environments safe

📖 **Full guide:** [UNINSTALL.md](UNINSTALL.md)

---

## ❓ Need Help?

- Run `uvm help` for command reference
- Check [README.md#troubleshooting](README.md#-troubleshooting) for common issues
- Open an issue on GitHub

---

**Happy coding with uvm! 🎉**

