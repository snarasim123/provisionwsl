#!/usr/bin/env bash
##############################################################################
# Alpine Python Installation Functions
# Source this file from prep-install.sh for Alpine support
##############################################################################

# Uses variables from prep-install.sh:
# PYTHON_VERSION, PYTHON_CMD, PYTHON_BIN, PIP_CMD, PIP_LOCAL_BIN
#
# Note: Alpine uses different package naming conventions:
# - python3 (not python3.11)
# - py3-pip (not python3-pip)
# Alpine's package repos may not have all Python versions available

remove_python_alpine() {
    # Remove pre-installed Python packages
    # Be careful - some Alpine tools may depend on Python
    sudo apk del py3-pip 2>/dev/null || true
}

install_python_alpine() {
    # Update package index
    sudo apk update
    
    # Install GNU tar and unzip (required for Ansible unarchive module)
    # Alpine's default BusyBox tar is not compatible with Ansible
    echo "Installing GNU tar and unzip for Ansible compatibility..."
    sudo apk add --no-cache tar gzip unzip zip
    
    # Install Python 3 and related packages
    # Alpine package naming: python3, py3-pip, python3-dev
    echo "Installing Python on Alpine..."
    
    # Install core Python packages
    sudo apk add --no-cache python3 python3-dev py3-pip
    
    # Create symlinks for python if not exists
    if [ ! -f /usr/bin/python ]; then
        sudo ln -sf /usr/bin/python3 /usr/bin/python
    fi
    
    # Install build dependencies for compiling Python packages
    sudo apk add --no-cache \
        build-base \
        libffi-dev \
        openssl-dev \
        bzip2-dev \
        zlib-dev \
        readline-dev \
        sqlite-dev \
        xz-dev
    
    # Install packages available via apk first (preferred method)
    sudo apk add --no-cache py3-cryptography py3-passlib
    
    # Upgrade pip (use --break-system-packages for PEP 668 compliance)
    sudo python3 -m pip install --upgrade pip --break-system-packages
    
    # Install any additional packages not available via apk
    # Using --break-system-packages to override PEP 668 protection
    # This is safe for WSL/container environments
    sudo python3 -m pip install --upgrade cryptography --break-system-packages 2>/dev/null || true
    sudo python3 -m pip install passlib --break-system-packages 2>/dev/null || true
}

verify_python_alpine() {
    echo "=== Python Installation Verification (Alpine) ==="
    echo "Note: Alpine uses system Python (python3)"
    echo ""
    
    echo "--- Python Versions ---"
    echo -n "python3: "; python3 --version 2>&1 || echo "NOT INSTALLED"
    echo -n "python:  "; python --version 2>&1 || echo "NOT INSTALLED"
    echo ""
    
    echo "--- Pip Versions ---"
    echo -n "pip3: "; python3 -m pip --version 2>&1 || echo "NOT INSTALLED"
    echo -n "pip:  "; pip --version 2>&1 || echo "NOT INSTALLED"
    echo ""
    
    echo "--- Python Module Tests ---"
    python3 -c "import cryptography; print('cryptography: OK (' + cryptography.__version__ + ')')" 2>&1 || echo "cryptography: FAILED"
    python3 -c "import passlib; print('passlib:      OK')" 2>&1 || echo "passlib:      FAILED"
    echo ""
    
    echo "--- Ansible ---"
    ansible --version 2>&1 | head -4 || echo "Ansible: NOT INSTALLED"
    echo ""
    
    echo "--- Python Paths ---"
    echo -n "python3 path: "; which python3 2>&1 || echo "NOT FOUND"
    echo -n "python path:  "; which python 2>&1 || echo "NOT FOUND"
    echo ""
    
    echo "=== Verification Complete ==="
}
