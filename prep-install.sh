##############################################################################
# Python Version Configuration
# Change these variables to install a different Python version
##############################################################################
PYTHON_VERSION="3.11"                                    # e.g., "3.11", "3.12", "3.13"
PYTHON_CMD="python${PYTHON_VERSION}"                     # e.g., python3.11
PYTHON_BIN="/usr/bin/${PYTHON_CMD}"                      # e.g., /usr/bin/python3.11
PYTHON_DEV_PKG="${PYTHON_CMD}-dev"                       # e.g., python3.11-dev
PYTHON_VENV_PKG="${PYTHON_CMD}-venv"                     # e.g., python3.11-venv
PYTHON_DISTUTILS_PKG="${PYTHON_CMD}-distutils"           # e.g., python3.11-distutils

# Pip version-specific paths
PIP_CMD="pip${PYTHON_VERSION}"                           # e.g., pip3.11
PIP_LOCAL_BIN="/usr/local/bin/${PIP_CMD}"                # e.g., /usr/local/bin/pip3.11
##############################################################################

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

upgrade() {
    if [[ "$distro_type" == "ubuntu" ]] ; then
        sudo apt update -y
        sudo apt upgrade -y
        sudo apt install unzip -y
        
        remove_python_ubuntu
        install_python_ubuntu
        
        # Install Ansible via pip (ensures it uses configured Python version)
        sudo ${PYTHON_CMD} -m pip install ansible
        sudo apt install aptitude -y
        ansible-galaxy collection install community.general
        ansible-galaxy collection install kubernetes.core
    elif [[ "$distro_type" == "alpine" ]] ; then
        # echo "alpine upgrade"
        apk add sudo
        sudo apk update
        sudo apk add bash              
        sudo apk add lsb-release     
        sudo apk add --no-cache openssh
        sudo apk add --no-cache py3-passlib 
        sudo apk add ansible

        ansible-galaxy collection install community.general
    elif [[ "$distro_type" == "fedora" ]] ; then
        sudo dnf install ansible -y
        ansible-galaxy collection install community.general
    fi
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

profile_path=$1
source $profile_path

echo "##### Preparing instance $distro_name, doing preliminary setup ....."

# read -p "*** Prelim installs for $distro_type, Press to continue.. " -n 1 -r
if [[ "$upgrade" == "true" ]] ; then
    upgrade
    if [[ "$distro_type" == "ubuntu" ]] ; then
        verify_python_ubuntu
    fi
fi

exit

