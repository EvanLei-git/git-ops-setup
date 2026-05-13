#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "========================================"
echo " Starting Ansible Installation Process"
echo "========================================"

# Step 1: Locate Python
if command -v python3 >/dev/null 2>&1; then
    echo "[✓] Found Python: $(python3 --version)"
else
    echo "[!] Error: python3 is not installed. Please install Python 3 first."
    exit 1
fi

# Step 2: Select and execute the installation method
if command -v pipx >/dev/null 2>&1; then
    echo "[✓] Found pipx. Proceeding with pipx installation (Recommended)..."
    
    # Install the full Ansible package
    echo "--> Installing the full Ansible package via pipx..."
    pipx install --include-deps ansible
    
    # Install Extra Python Dependencies (argcomplete for shell completion)
    echo "--> Injecting argcomplete for command shell completion..."
    pipx inject --include-apps ansible argcomplete
    
else
    echo "[i] pipx not found. Falling back to pip installation..."
    
    # Ensure pip is available
    if ! python3 -m pip -V >/dev/null 2>&1; then
        echo "--> pip not found. Bootstrapping pip..."
        curl -sS https://bootstrap.pypa.io/get-pip.py -o get-pip.py
        python3 get-pip.py --user
        rm -f get-pip.py
    else
        echo "[✓] Found pip: $(python3 -m pip -V)"
    fi
    
    # Install the full Ansible package
    echo "--> Installing the full Ansible package via pip..."
    python3 -m pip install --user ansible
    
    # Install Extra Python Dependencies
    echo "--> Installing argcomplete for command shell completion..."
    python3 -m pip install --user argcomplete
fi

# Temporarily add user local bin to PATH for the remainder of this script execution
export PATH="$HOME/.local/bin:$PATH"

# Step 3: Configure shell completion globally
echo "--> Configuring argcomplete globally..."
if command -v activate-global-python-argcomplete >/dev/null 2>&1; then
    activate-global-python-argcomplete --user
    echo "[✓] argcomplete configured successfully."
else
    echo "[!] Warning: activate-global-python-argcomplete not found in PATH."
    echo "    You may need to manually configure it or add ~/.local/bin to your PATH."
fi

# Step 4: Confirm your installation
echo "========================================"
echo " Confirming Ansible Installation"
echo "========================================"

if command -v ansible >/dev/null 2>&1; then
    ansible --version
    echo -e "\n[✓] Ansible installation completed successfully!"
else
    echo -e "\n[i] Installation finished, but the 'ansible' command is not currently in your PATH."
fi

echo ""
echo "Note: If your system cannot find the 'ansible' command, please ensure that '$HOME/.local/bin' is added to your shell's PATH variable."
echo "You can do this by adding 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your ~/.bashrc, ~/.zshrc, or ~/.profile."