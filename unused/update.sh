# pass the distro type name (ubuntu/alpine/fedora) to update the index and
# install ansible.

upgrade() {
    dist_type=$1
    if [[ "$dist_type" == "ubuntu" ]] ; then
        sudo apt update -y
        sudo apt upgrade -y
        sudo apt install unzip -y
        sudo apt install ansible aptitude -y
        ansible-galaxy collection install community.general
        ansible-galaxy collection install kubernetes.core

    elif [[ "$dist_type" == "alpine" ]] ; then
        # echo "alpine upgrade"
        apk add sudo
        sudo apk update
        sudo apk add bash              
        sudo apk add lsb-release     
        sudo apk add --no-cache openssh
        sudo apk add --no-cache py3-passlib 
        sudo apk add ansible
        ansible-galaxy collection install community.general

    elif [[ "$dist_type" == "fedora" ]] ; then
        sudo dnf up --refresh

        sudo dnf install ansible -y
        ansible-galaxy collection install community.general
    fi
}

