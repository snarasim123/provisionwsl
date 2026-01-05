#!/usr/bin/env bash

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
    mkdir "$HOME/code/$code_root"  -p
    cd "$HOME/code"
    rm -rf ./*
    rm -rf ./.*
    copy_and_skip_type "$code_src" "$HOME/code/$code_root" "vhdx"
}

run-ansible(){
    echo "#### Ansible setup."
    cd "$HOME/code/$code_root/ansible"
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
    cd "$HOME/code/$code_root/ansible"
    chmod -x secrets.*
    ansible-playbook  -i hosts -e @secrets.yaml --vault-password-file secrets.pass ./playbook.yaml --check
    # echo "#### Done check."
}

# read -p "*** Press to continue.. " -n 1 -r
profile_path=$1
scriptroot_path=$2
source $profile_path

echo "#### install.sh: profile_path = $profile_path scriptroot = $scriptroot_path"

clone-repo
if [[ "$debug_mode" == "check" ]] ; then
    run-ansible-check        
else
    run-ansible
fi
exit

