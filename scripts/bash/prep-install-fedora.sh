#!/usr/bin/env bash
##############################################################################
# Fedora Python Installation Functions
# Source this file from prep-install.sh for Fedora support
##############################################################################

# Uses variables from prep-install.sh:
# PYTHON_VERSION, PYTHON_CMD, PYTHON_BIN, PYTHON_DEV_PKG, PIP_CMD, PIP_LOCAL_BIN

remove_python_fedora() {
    # Remove pre-installed Python versions (be careful - Fedora depends on Python)
    # Only remove pip, not Python itself as dnf depends on it
    sudo dnf remove -y python3-pip 2>/dev/null || true
}

build_python3_dnf() {
    # Fedora's dnf module works with the system Python
    # For custom Python versions, we need to install python3-dnf separately
    # This is typically not needed on Fedora as the system Python handles dnf
    
    echo "Note: Fedora's dnf uses the system Python. Custom Python version installed separately."
    
    # Install dnf python bindings if needed
    sudo dnf install -y python3-dnf python3-libdnf 2>/dev/null || true
}

install_python_fedora() {
    # Install dependencies for Python
    sudo dnf install -y dnf-plugins-core
    
    # Install Python (Fedora usually has recent Python in repos)
    echo "Installing Python ${PYTHON_VERSION} on Fedora..."
    
    # Try to install the specific version
    # Fedora package naming: python3.11, python3.12, etc.
    sudo dnf install -y ${PYTHON_CMD} ${PYTHON_CMD}-devel ${PYTHON_CMD}-pip 2>/dev/null || {
        # If specific version not available, try alternate package names
        echo "Trying alternate package names..."
        sudo dnf install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-devel python${PYTHON_VERSION}-pip 2>/dev/null || {
            echo "WARNING: Python ${PYTHON_VERSION} not found in repos. Using system Python."
            return 1
        }
    }
    
    # Install pip for the configured Python version if not already installed
    ${PYTHON_CMD} -m ensurepip --upgrade 2>/dev/null || \
        curl -sS https://bootstrap.pypa.io/get-pip.py | sudo ${PYTHON_CMD}
    
    # Set configured Python as alternative (don't override system python3 on Fedora)
    sudo alternatives --install /usr/bin/python python ${PYTHON_BIN} 1 2>/dev/null || true
    
    # Update pip symlinks
    sudo ln -sf ${PIP_LOCAL_BIN} /usr/bin/pip 2>/dev/null || true
    
    # Install dependencies for cryptography
    sudo dnf install -y openssl-devel libffi-devel rust cargo gcc
    
    # Install cryptography library for ansible-vault
    sudo ${PYTHON_CMD} -m pip install --upgrade pip
    sudo ${PYTHON_CMD} -m pip install --upgrade cryptography
    
    # Install passlib for Ansible password_hash filter
    sudo ${PYTHON_CMD} -m pip install passlib
}

verify_python_fedora() {
    echo "=== Python Installation Verification (Fedora) ==="
    echo "Configured Python Version: ${PYTHON_VERSION}"
    echo ""
    
    echo "--- Python Versions ---"
    echo -n "${PYTHON_CMD}: "; ${PYTHON_CMD} --version 2>&1 || echo "NOT INSTALLED"
    echo -n "python3:    "; python3 --version 2>&1 || echo "NOT INSTALLED"
    echo -n "python:     "; python --version 2>&1 || echo "NOT INSTALLED"
    echo ""
    
    echo "--- Pip Versions ---"
    echo -n "${PIP_CMD}: "; ${PYTHON_CMD} -m pip --version 2>&1 || echo "NOT INSTALLED"
    echo -n "pip3:    "; pip3 --version 2>&1 || echo "NOT INSTALLED"
    echo -n "pip:     "; pip --version 2>&1 || echo "NOT INSTALLED"
    echo ""
    
    echo "--- Python Module Tests ---"
    ${PYTHON_CMD} -c "import dnf; print('dnf:          OK')" 2>&1 || echo "dnf:          FAILED (expected for non-system Python)"
    ${PYTHON_CMD} -c "import cryptography; print('cryptography: OK (' + cryptography.__version__ + ')')" 2>&1 || echo "cryptography: FAILED"
    ${PYTHON_CMD} -c "import passlib; print('passlib:      OK')" 2>&1 || echo "passlib:      FAILED"
    echo ""
    
    echo "--- Ansible ---"
    ansible --version 2>&1 | head -4 || echo "Ansible: NOT INSTALLED"
    echo ""
    
    echo "--- Python Paths ---"
    echo -n "${PYTHON_CMD} path: "; which ${PYTHON_CMD} 2>&1 || echo "NOT FOUND"
    echo -n "python3 path:    "; which python3 2>&1 || echo "NOT FOUND"
    echo -n "python path:     "; which python 2>&1 || echo "NOT FOUND"
    echo ""
    
    echo "=== Verification Complete ==="
}
