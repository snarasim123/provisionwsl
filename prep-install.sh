
upgrade() {
    if [[ "$distro_type" == "ubuntu" ]] ; then
        sudo apt update -y
        sudo apt upgrade -y
        sudo apt install unzip -y
        sudo apt install ansible aptitude -y
        ansible-galaxy collection install community.general
        ansible-galaxy collection install kubernetes.core
    elif [[ "$distro_type" == "alpine" ]] ; then
        # echo "alpine upgrade"
        apk add sudo
        sudo apk update
        sudo apk add bash              
        sudo apk add lsb-release     
        sudo apk add --no-cache openssh
        sudo apk add --no-cache py3-passlib 
        sudo apk add ansible

        ansible-galaxy collection install community.general
    elif [[ "$distro_type" == "fedora" ]] ; then
        sudo dnf install ansible -y
        ansible-galaxy collection install community.general
    fi
}

profile_path=$1
source $profile_path

echo "##### Preparing instance $distro_name, doing preliminary setup ....."

# read -p "*** Prelim installs for $distro_type, Press to continue.. " -n 1 -r
if [[ "$upgrade" == "true" ]] ; then
    upgrade
fi

exit

