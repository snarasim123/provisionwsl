#!/usr/bin/env bash
##############################################################################
# Ubuntu Python Installation Functions
# Source this file from prep-install.sh for Ubuntu support
##############################################################################

# Uses variables from prep-install.sh:
# PYTHON_VERSION, PYTHON_CMD, PYTHON_BIN, PYTHON_DEV_PKG, PYTHON_VENV_PKG,
# PYTHON_DISTUTILS_PKG, PIP_CMD, PIP_LOCAL_BIN

remove_python_ubuntu() {
    # Remove pre-installed Python versions
    sudo apt remove -y python3 python3-pip python3-venv 2>/dev/null || true
    sudo apt autoremove -y
}

build_python3_apt() {
    # Build python3-apt from Ubuntu's source for the configured Python version
    # Install build dependencies
    sudo apt install -y build-essential libapt-pkg-dev ${PYTHON_DEV_PKG} dpkg-dev
    
    # Enable deb-src repositories (required for apt-get source)
    sudo sed -i 's/^# deb-src/deb-src/' /etc/apt/sources.list
    sudo apt update -y
    
    # Get Ubuntu's python-apt source (matches installed libapt-pkg version)
    cd /tmp
    sudo rm -rf python-apt-build 2>/dev/null || true
    mkdir python-apt-build
    cd python-apt-build
    
    # Download Ubuntu's python-apt source package
    apt-get source python-apt
    
    # Find and enter the source directory
    PYTHON_APT_DIR=$(ls -d python-apt-*/ 2>/dev/null | head -1)
    if [ -z "$PYTHON_APT_DIR" ]; then
        echo "ERROR: Failed to download python-apt source"
        return 1
    fi
    cd "$PYTHON_APT_DIR"
    
    # Build and install for configured Python version using pip (avoids setup.py deprecation)
    sudo ${PYTHON_CMD} -m pip install .
    
    # Cleanup
    cd /tmp
    sudo rm -rf python-apt-build
}

install_python_ubuntu() {
    # Install dependencies for Python
    sudo apt install -y software-properties-common
    
    # Add deadsnakes PPA for Python
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt update -y
    
    # Install Python (version from PYTHON_VERSION variable)
    echo "Installing Python ${PYTHON_VERSION}..."
    sudo apt install -y ${PYTHON_CMD} ${PYTHON_VENV_PKG} ${PYTHON_DEV_PKG} ${PYTHON_DISTUTILS_PKG}
    
    # Install pip for the configured Python version
    curl -sS https://bootstrap.pypa.io/get-pip.py | sudo ${PYTHON_CMD}
    
    # Set configured Python as the default python3
    sudo update-alternatives --install /usr/bin/python3 python3 ${PYTHON_BIN} 1
    sudo update-alternatives --set python3 ${PYTHON_BIN}
    
    # Set configured Python as the default python
    sudo update-alternatives --install /usr/bin/python python ${PYTHON_BIN} 1
    sudo update-alternatives --set python ${PYTHON_BIN}
    
    # Update pip symlinks
    sudo ln -sf ${PIP_LOCAL_BIN} /usr/bin/pip3 2>/dev/null || true
    sudo ln -sf ${PIP_LOCAL_BIN} /usr/bin/pip 2>/dev/null || true
    
    # Build python3-apt for configured Python version (required for Ansible apt module)
    build_python3_apt
    
    # Install dependencies for cryptography
    sudo apt install -y libssl-dev libffi-dev rustc cargo
    
    # Install cryptography library for ansible-vault
    sudo ${PYTHON_CMD} -m pip install --upgrade pip
    sudo ${PYTHON_CMD} -m pip install --upgrade cryptography
    
    # Install passlib for Ansible password_hash filter
    sudo ${PYTHON_CMD} -m pip install passlib
}

verify_python_ubuntu() {
    echo "=== Python Installation Verification ==="
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
    ${PYTHON_CMD} -c "import apt; print('apt:          OK')" 2>&1 || echo "apt:          FAILED"
    ${PYTHON_CMD} -c "import apt_pkg; print('apt_pkg:      OK')" 2>&1 || echo "apt_pkg:      FAILED"
    ${PYTHON_CMD} -c "import cryptography; print('cryptography: OK (' + cryptography.__version__ + ')')" 2>&1 || echo "cryptography: FAILED"
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
