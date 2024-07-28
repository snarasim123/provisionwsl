source ./variables.sh
distro_type=$1
upgrade() {
    if [[ "$distro_type" == "ubuntu" ]] ; then
        sudo apt update -y
        sudo apt upgrade -y
        sudo apt install ansible aptitude -y
        ansible-galaxy collection install community.general
    # elif [[ "$distro_type" == "fedora" ]] ; then
        # echo "fedora upgrade"
    elif [[ "$distro_type" == "alpine" ]] ; then
        # echo "alpine upgrade"
        apk update
        apk add sudo
        apk add bash              
        apk add lsb-release          
        apk add --no-cache openssh
        apk add py3-passlib
        sudo apk add ansible
        ansible-galaxy collection install community.general
    elif [[ "$distro_type" == "fedora" ]] ; then
        sudo dnf install ansible -y
        ansible-galaxy collection install community.general
    fi
}


distro_type=$1
# read -p "*** Prelim installs for $distro_type, Press to continue.. " -n 1 -r
upgrade
exit

