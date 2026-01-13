#!/usr/bin/env bash

get_script_info() {
    # Get the directory where this script is located
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Get the script's parent folder name (just the folder name, not full path)
    local parent_folder_name="$(basename "$script_dir")"
    
    # Get the full path to the parent folder
    local parent_folder_path="$script_dir"
    
    # Export these for use in other functions
    export SCRIPT_FOLDER_NAME="$parent_folder_name"
    export SCRIPT_FOLDER_PATH="$parent_folder_path"
    
    echo "Script folder name: $SCRIPT_FOLDER_NAME"
    echo "Script folder path: $SCRIPT_FOLDER_PATH"
}

copy_and_skip_type() {
    local src="$1" dst="$2" skip_ext="$3"
    mkdir -p "$dst"
    find "$src" -mindepth 1 -type d | while read -r d; do
        mkdir -p "$dst/${d#$src/}"
    done
    find "$src" -mindepth 1 -type f ! -name "*.$skip_ext" | while read -r f; do
        cp "$f" "$dst/${f#$src/}"
    done
}

clone-repo(){
    echo "#### clone repo."
    mkdir "$HOME/code/$SCRIPT_FOLDER_NAME"  -p
    cd "$HOME/code"
    rm -rf ./*
    rm -rf ./.*
    copy_and_skip_type "$SCRIPT_FOLDER_PATH" "$HOME/code/$SCRIPT_FOLDER_NAME" "vhdx"
}

run-ansible(){
    echo "#### Ansible setup."
    cd "$HOME/code/$SCRIPT_FOLDER_NAME"
    chmod -x secrets.*
    if [ -z ${skipsteps+x} ]; 
    then 
        echo "skipsteps is unset"; 
        ansible-playbook  -i hosts -e @secrets.yaml --vault-password-file secrets.pass ./playbook.yaml
    else 
        echo "skipsteps is set to '$skipsteps'"; 
        echo "executing ansible command..."
        echo "ansible-playbook  -i hosts -e @secrets.yaml --vault-password-file secrets.pass ./playbook.yaml --skip-tags=$skipsteps"
        ansible-playbook  -i hosts -e @secrets.yaml --vault-password-file secrets.pass ./playbook.yaml  --skip-tags="$skipsteps"
    fi    
}
run-ansible-check(){
    # echo "#### Ansible check."
    cd "$HOME/code/$SCRIPT_FOLDER_NAME/ansible"
    chmod -x secrets.*
    ansible-playbook  -i hosts -e @secrets.yaml --vault-password-file secrets.pass ./playbook.yaml --check
    # echo "#### Done check."
}

# read -p "*** Press to continue.. " -n 1 -r
profile_path=$1
scriptroot_path=$2
source $profile_path

# Get script location information
get_script_info

echo "#### install.sh: profile_path = $profile_path scriptroot = $scriptroot_path"

clone-repo
if [[ "$debug_mode" == "check" ]] ; then
    run-ansible-check        
else
    run-ansible
fi
exit

