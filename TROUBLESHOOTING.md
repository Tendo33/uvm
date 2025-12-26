# Troubleshooting Guide

## "Environment not found" Error

### Problem
You see environments with `uvm list` but get "Environment 'xxx' not found" when trying to activate:

```bash
$ uvm list
Available environments:
  llm                       Python 3.12.9     /d/envs/llm

$ uvm activate llm
Error: Environment 'llm' not found
```

### Root Causes

1. **Shell hook not loaded**: The `uvm` command is still a script instead of a shell function
2. **Configuration not loaded**: `UVM_ENVS_DIR` environment variable is not set correctly
3. **Environments not registered**: Existing environments were not registered in `envs.json`

### Solutions

#### Step 1: Verify Shell Hook is Loaded

Check if `uvm` is a function:

```bash
type uvm
```

**Expected output**: `uvm is a function`  
**If you see**: `uvm is /path/to/uvm` → Shell hook is NOT loaded

#### Step 2: Reload Shell Configuration

**For Bash users:**
```bash
source ~/.bashrc
```

**For Zsh users:**
```bash
source ~/.zshrc
```

**Important**: Make sure the shell-hook line is in the CORRECT config file:
- If using **bash** → add to `~/.bashrc`
- If using **zsh** → add to `~/.zshrc`

Check your current shell:
```bash
echo $SHELL
```

#### Step 3: Verify Configuration

After reloading, check:

```bash
# Should show your environments directory
echo $UVM_ENVS_DIR

# Should show "uvm is a function"
type uvm
```

#### Step 4: Register Existing Environments

If you have existing UV environments that were created before installing uvm:

```bash
# Scan and register all environments in your directory
uvm scan /path/to/your/envs

# Or use the default directory
uvm scan
```

#### Step 5: Test Activation

```bash
uvm list
uvm activate llm
```

---

## Windows + Git Bash + Oh My Zsh

### Special Considerations

If you're using **Oh My Zsh** on Windows with Git Bash:

1. **Check which shell you're actually using**:
   ```bash
   echo $SHELL
   ps -p $$
   ```

2. **Add shell-hook to the correct file**:
   - If `$SHELL` shows `/usr/bin/bash` → use `~/.bashrc`
   - If `$SHELL` shows `/usr/bin/zsh` → use `~/.zshrc`

3. **Reload the correct file**:
   ```bash
   source ~/.bashrc  # or ~/.zshrc
   ```

### Common Mistake

❌ **Wrong**: Adding `eval "$(uvm shell-hook)"` to `.zshrc` while using bash  
✅ **Correct**: Add to `.bashrc` if using bash, or `.zshrc` if using zsh

---

## Environment Directory Configuration

### Check Current Configuration

```bash
cat ~/.config/uvm/config
```

Should show:
```bash
UVM_ENVS_DIR="/path/to/your/envs"
```

### Change Environment Directory

If you want to use a different directory:

1. Edit the config file:
   ```bash
   echo 'UVM_ENVS_DIR="/d/envs"' > ~/.config/uvm/config
   ```

2. Reload shell:
   ```bash
   source ~/.bashrc  # or ~/.zshrc
   ```

3. Scan and register environments:
   ```bash
   uvm scan /d/envs
   ```

---

## Verify Installation

Run this complete check:

```bash
#!/bin/bash

echo "=== UVM Installation Check ==="
echo ""

echo "1. Shell:"
echo "   Current: $SHELL"
echo ""

echo "2. UVM Command:"
type uvm
echo ""

echo "3. Configuration:"
echo "   UVM_HOME: ${UVM_HOME:-not set}"
echo "   UVM_ENVS_DIR: ${UVM_ENVS_DIR:-not set}"
echo ""

echo "4. Config File:"
cat ~/.config/uvm/config 2>/dev/null || echo "   Config file not found"
echo ""

echo "5. Registered Environments:"
cat ~/.config/uvm/envs.json 2>/dev/null | python -m json.tool || echo "   envs.json not found"
echo ""

echo "6. Available Environments:"
uvm list
```

Save this as `check_uvm.sh` and run:
```bash
bash check_uvm.sh
```

---

## Still Having Issues?

1. **Completely reload shell**: Close and reopen your terminal
2. **Reinstall shell hook**: 
   ```bash
   uvm init
   ```
3. **Check for conflicts**: Make sure no other tool is overriding the `uvm` command
4. **Manual activation** (temporary workaround):
   ```bash
   source /path/to/env/Scripts/activate  # Windows
   source /path/to/env/bin/activate      # Linux/macOS
   ```

