#!/usr/bin/env bash
set -eo pipefail
trap 'echo "ERROR: Python preparation failed. Inspect the error above; system Python will not be replaced as a workaround." >&2' ERR

scriptroot_path=${2:?Usage: prep-install.sh PROFILE REPOSITORY_ROOT [USER]}
source "$scriptroot_path/scripts/bash/python-bootstrap.sh"
CONTROLLER_PYTHON_VERSION="3.11"
source "$scriptroot_path/csv-utils.sh"

profile_path=${1:?Usage: prep-install.sh PROFILE REPOSITORY_ROOT [USER]}
distro_name=$(basename "$profile_path")
source "$profile_path"

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
        echo "ERROR: Could not load CSV record for $ps_distro_id" >&2
        exit 1
    fi
else
    echo "##### DEBUG: ps_distro_id is empty or not set, skipping CSV lookup"
fi

assert_supported_python_distro
configure_ansible_runtime
prepare_python
install_ansible_collections
validate_ansible_runtime

