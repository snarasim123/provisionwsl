source ./variables.sh

upgrade() {
    if [[ "$distro_type" == "ubuntu" ]] ; then
        sudo apt update -y
        sudo apt upgrade -y
        sudo apt install ansible aptitude -y
        ansible-galaxy collection install community.general
        ansible-galaxy collection install kubernetes.core
        # ansible-galaxy collection install community.kubernetes
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
skip_upgrade=$2

# read -p "*** Prelim installs for $distro_type, Press to continue.. " -n 1 -r
if [[ "$skip_upgrade" != "false" ]] ; then
    echo "###### Upgrade distro $distro_type ....."
    upgrade
else 
    echo "###### Skipping $distro_type upgrade ....."
fi

exit

