#!/usr/bin/env bash
source ./variables.sh

# upgrade() {
#     if [[ "$distro_type" == "ubuntu" ]] ; then
#         sudo apt update -y
#         sudo apt upgrade -y
#     elif [[ "$distro_type" == "fedora" ]] ; then
#         echo "fedora upgrade"
#     elif [[ "$distro_type" == "alpine" ]] ; then
#         echo "alpine upgrade"
#         apk update                
#         apk add --no-cache openssh
#         # apk add --no-cache openssh-keygen
#     fi
# }

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
    # if [[ "$distro_type" == "ubuntu" ]] ; then
    #     sudo apt install ansible aptitude -y
    # elif [[ "$distro_type" == "fedora" ]] ; then
    #     sudo dnf install ansible -y
    # elif [[ "$distro_type" == "alpine" ]] ; then
    #     sudo apk add ansible
    # fi

    # ansible-galaxy collection install community.general

    cd "$HOME/code/setup/ansible"
    chmod -x secrets.*
    ansible-playbook  -i hosts -e @secrets.yaml --vault-password-file secrets.pass ./playbook.yaml
    echo "#### Done Preliminary setup."
}

# read -p "*** Press to continue.. " -n 1 -r
# upgrade
distro_type=$1
# read -p "*** install for $distro_type, Press to continue.. " -n 1 -r
clone-repo
run-ansible
exit

