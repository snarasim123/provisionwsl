#!/usr/bin/env bash

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
    
    # ansible-playbook  -i hosts -e @secrets.yaml --vault-password-file secrets.pass ./playbook.yaml
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
profile_path=$1
source $profile_path
echo "###### install.sh, reading profile  $profile_path ....."
echo "###### Setting instance, type  $distro_type , upgrade true/false? $upgrade....."
# distro_type=$1
# debug_mode=$2
# read -p "*** install for $distro_type, Press to continue.. " -n 1 -r
clone-repo
if [[ "$debug_mode" == "check" ]] ; then
    run-ansible-check        
else
    run-ansible
fi
exit

