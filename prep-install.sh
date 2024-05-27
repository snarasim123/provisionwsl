source ./variables.sh

upgrade() {
    if [[ "$distro_type" == "ubuntu" ]] ; then
        sudo apt update -y
        sudo apt upgrade -y
    # elif [[ "$distro_type" == "fedora" ]] ; then
        # echo "fedora upgrade"
    elif [[ "$distro_type" == "alpine" ]] ; then
        # echo "alpine upgrade"
        apk update
        apk add sudo
        apk add bash                        
        apk add --no-cache openssh
        # echo "Installing passlib"
        apk add py3-passlib
        # apk add py3-pip
        # python3 -m pip install passlib
    fi
}


# read -p "*** Press to continue.. " -n 1 -r
upgrade
exit

