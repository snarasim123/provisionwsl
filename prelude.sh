#!/usr/bin/env bash
source ./variables.sh

upgrade() {
    if [[ "$distro_type" == "ubuntu" ]] ; then
        sudo apt update -y
        sudo apt upgrade -y
    elif [[ "$distro_type" == "fedora" ]] ; then
        echo "fedora upgrade"
    fi
}

clone-repo(){
    echo "#### clone repo."
    mkdir "$HOME/code"  -p
    cd "$HOME/code"
    rm -rf ./*
    rm -rf ./.*
    cp -r /mnt/d/code/setup "$HOME/code"
    echo "#### Done Clone repo."
}

run-ansible(){
    echo "#### Ansible setup."
    if [[ "$distro_type" == "ubuntu" ]] ; then
        sudo apt install ansible aptitude -y
    elif [[ "$distro_type" == "fedora" ]] ; then
        sudo dnf install ansible -y
    fi

    ansible-galaxy collection install community.general

    cd "$HOME/code/setup/ansible"
    chmod -x secrets.*
    ansible-playbook  -i hosts -e @secrets.yaml --vault-password-file secrets.pass ./playbook.yaml
    echo "#### Done Preliminary setup."
}

# read -p "*** Press to continue.. " -n 1 -r
upgrade
clone-repo
run-ansible
exit

