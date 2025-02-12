#!/usr/bin/env bash
source ./variables.sh

clone-repo(){
    echo "#### clone repo."
    mkdir "$HOME/code"  -p
    cd "$HOME/code"
    rm -rf ./*
    rm -rf ./.*
    cp -r $code_src "$HOME/code"
    echo "#### Done Clone repo."
}

run-ansible(){
    echo "#### Ansible setup."
    cd "$HOME/code/$code_root/ansible"
    chmod -x secrets.*
    ansible-playbook  -i hosts -e @secrets.yaml --vault-password-file secrets.pass ./playbook.yaml
    # --skip-tags=aws_install,bash,bash_extra,k9s_install,vim,nvim,folders,git,packages,upgrade,user,print, --step
    echo "#### Done setup."
}
run-ansible-check(){
    echo "#### Ansible check."
    cd "$HOME/code/$code_root/ansible"
    chmod -x secrets.*
    ansible-playbook  -i hosts -e @secrets.yaml --vault-password-file secrets.pass ./playbook.yaml --check
    echo "#### Done check."
}

# read -p "*** Press to continue.. " -n 1 -r
# upgrade
distro_type=$1
debug_mode=$2
# read -p "*** install for $distro_type, Press to continue.. " -n 1 -r
clone-repo
if [[ "$debug_mode" == "--check" ]] ; then
    run-ansible-check        
else
    run-ansible
fi
exit

