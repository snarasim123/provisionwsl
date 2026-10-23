#!/usr/bin/env bash
set -eo pipefail

scriptroot_path=${2:?Usage: install.sh PROFILE REPOSITORY_ROOT [USER]}
source "$scriptroot_path/scripts/bash/python-bootstrap.sh"
read_python_bootstrap_mode "$scriptroot_path"
require_prepared_python_mode

get_script_info() {
    echo "#### get_script_info."
    # Get the directory where this script is located
    local script_dir="$scriptroot_path"
    
    # Get the script's parent folder name (just the folder name, not full path)
    local parent_folder_name="$(basename "$script_dir")"
    
    # Get the full path to the parent folder
    local parent_folder_path="$script_dir"
    
    # Export these for use in other functions
    export SCRIPT_FOLDER_NAME="$parent_folder_name"
    export SCRIPT_FOLDER_PATH="$parent_folder_path"
    
    echo "Script folder name: $SCRIPT_FOLDER_NAME"
    echo "Script folder path: $SCRIPT_FOLDER_PATH"
    echo "#### done get_script_info."
}

copy_and_skip_type() {
    echo "#### copy_and_skip_type."
    local src="$1" dst="$2" skip_ext="$3"
    mkdir -p "$dst"
    find "$src" -mindepth 1 -type d | while read -r d; do
        mkdir -p "$dst/${d#$src/}"
    done
    find "$src" -mindepth 1 -type f ! -name "*.$skip_ext" | while read -r f; do
        # echo "Copying $f to $dst/${f#$src/}"
        cp "$f" "$dst/${f#$src/}"
    done
    echo "#### done copy_and_skip_type."
}

clone-repo(){
    echo "#### clone repo."
    mkdir "$HOME/code/$SCRIPT_FOLDER_NAME"  -p
    cd "$HOME/code"
    # rm -rf ./*
    # rm -rf ./.*
    copy_and_skip_type "$SCRIPT_FOLDER_PATH" "$HOME/code/$SCRIPT_FOLDER_NAME" "vhdx"
    echo "#### done clone repo."
}

run-ansible(){
    echo "#### Ansible setup."
    cd "$HOME/code/$SCRIPT_FOLDER_NAME" || return
    local cur_dir="$(pwd)"
    echo "#### current dir $cur_dir"
    local ls_list="$(ls -alR $HOME/code)"
    # echo "#### list of files  $ls_list"    
    chmod -x secrets.* 2>/dev/null || true

    # Include secrets only when github is not being skipped
    local secrets_args=""
    # if [ -z ${skipsteps+x} ] || ! echo "$skipsteps" | grep -qi "github"; then
    #     secrets_args="-e @secrets.yaml --vault-password-file secrets.pass"
    # else
    #     echo "github is in skipsteps — skipping secrets"
    # fi

    local ansible_args=(-i hosts ./playbook.yaml)
    if [[ -n "${skipsteps:-}" ]]; then
        ansible_args+=(--skip-tags "$skipsteps")
    fi
    ansible_args+=("$@")
    printf '#### Running: ansible-playbook'
    printf ' %q' "${ansible_args[@]}"
    printf '\n'
    "$ANSIBLE_PLAYBOOK" $secrets_args "${ansible_args[@]}" \
        -e "python_bootstrap_mode=$PYTHON_BOOTSTRAP_MODE" \
        -e "ansible_python_interpreter=$MANAGED_PYTHON"
}
run-ansible-check(){
    run-ansible --check
}

# read -p "*** Press to continue.. " -n 1 -r
profile_path=$1
source "$profile_path"
source "$scriptroot_path/csv-utils.sh"
if [[ -n "${ps_distro_id:-}" ]]; then
    get_csv_record "$ps_distro_id" "$scriptroot_path"
fi
case "$distro_type" in
    ubuntu|fedora|alpine) ;;
    *) echo "ERROR: Profile must select a supported distro_type or ps_distro_id." >&2; exit 1 ;;
esac
configure_ansible_runtime
validate_ansible_runtime

# Accept default_user from 3rd arg (passed from kickoff.ps1, sourced from Ansible vars)
if [[ -n "$3" ]]; then
    export default_user="$3"
fi

# Get script location information
get_script_info

echo "#### install.sh: profile_path = $profile_path scriptroot = $scriptroot_path default_user = $default_user"

clone-repo
if [[ "$debug_mode" == "check" ]] ; then
    run-ansible-check        
else
    run-ansible
fi
