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

# Get script directory for sourcing other scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility and distro-specific functions
source "${SCRIPT_DIR}/csv-utils.sh"
source "${SCRIPT_DIR}/scripts/bash/prep-install-ubuntu.sh"
source "${SCRIPT_DIR}/scripts/bash/prep-install-fedora.sh"
source "${SCRIPT_DIR}/scripts/bash/prep-install-alpine.sh"
##############################################################################

upgrade() {
    if [[ "$distro_type" == "ubuntu" ]] ; then
        sudo apt update -y
        sudo apt upgrade -y
        sudo apt install unzip -y
        
        remove_python_ubuntu
        install_python_ubuntu
        
        # Install Ansible via pip (use system Python if deadsnakes not available)
        if [ "$USE_SYSTEM_PYTHON" = true ]; then
            sudo python3 -m pip install ansible
        else
            sudo ${PYTHON_CMD} -m pip install ansible
        fi
        sudo apt install aptitude -y
        ansible-galaxy collection install community.general
        ansible-galaxy collection install kubernetes.core
    elif [[ "$distro_type" == "fedora" ]] ; then
        sudo dnf update -y
        sudo dnf install unzip -y
        
        remove_python_fedora
        install_python_fedora
        
        # Install Ansible via pip (ensures it uses configured Python version)
        sudo ${PYTHON_CMD} -m pip install ansible
        ansible-galaxy collection install community.general
        ansible-galaxy collection install kubernetes.core
    elif [[ "$distro_type" == "alpine" ]] ; then
        # Alpine upgrade and setup
        apk add sudo
        sudo apk update
        sudo apk add bash              
        sudo apk add lsb-release     
        sudo apk add --no-cache openssh
        
        remove_python_alpine
        install_python_alpine
        
        # Install Ansible via apk (Alpine package manager)
        sudo apk add ansible

        ansible-galaxy collection install community.general
    fi
}

profile_path=$1
scriptroot_path=$2
distro_name=$(basename "$profile_path")
source $profile_path

# Accept default_user from 3rd arg (passed from kickoff.ps1, sourced from Ansible vars)
if [[ -n "$3" ]]; then
    export default_user="$3"
fi

echo "##### Preparing instance , doing preliminary setup ....."
echo "##### profile_path = $profile_path distro_name = $distro_name distro_id = $ps_distro_id scriptroot = $scriptroot_path default_user = $default_user"

# Load CSV record for the distro_id from profile (if ps_distro_id is set)
if [[ -n "$ps_distro_id" ]]; then
    
    if get_csv_record "$ps_distro_id" "$scriptroot_path"; then
        echo "##### Distro id: $ps_distro_id"
        echo "##### Distro name: $distro_name"
        echo "##### Distro Type: $distro_type"
        echo "##### Distro URL: $download_url"                        
    else
        echo "##### WARNING: Could not load CSV record for $ps_distro_id"
    fi
else
    echo "##### DEBUG: ps_distro_id is empty or not set, skipping CSV lookup"
fi

# read -p "*** Prelim installs for $distro_type, Press to continue.. " -n 1 -r
# if [[ "$upgrade" == "true" ]] ; then
upgrade
if [[ "$distro_type" == "ubuntu" ]] ; then
    verify_python_ubuntu
elif [[ "$distro_type" == "fedora" ]] ; then
    verify_python_fedora
elif [[ "$distro_type" == "alpine" ]] ; then
    verify_python_alpine
fi
# fi

exit

