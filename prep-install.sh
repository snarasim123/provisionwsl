
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
        apk add sudo
        sudo apk update
        sudo apk add bash              
        sudo apk add lsb-release     

        sudo apk add --no-cache openssh
        # sudo apk del --no-cache ansible 
        sudo apk del --no-cache py3-passlib 
        sudo apk del --no-cache python3 
        sudo apk del --no-cache python3-dev 
        sudo apk del --no-cache py3-pip

        PYTHON_VERSION="3.8.9"
        PYTHON_MAJOR_VERSION="3.8"
        sudo apk add --no-cache build-base wget libffi-dev  libbz2 libffi zlib zlib-dev bzip2-dev readline-dev ncurses-dev xz-dev 
        #tk-dev  
        sudo apk add  ca-certificates 
        
        cd /tmp
        wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
        tar -xvzf Python-${PYTHON_VERSION}.tgz
        cd Python-${PYTHON_VERSION}
        ./configure --prefix=/usr/local
        make
        sudo make install

        sudo ln -sf "/usr/local/bin/python${PYTHON_MAJOR_VERSION}" /usr/bin/python3
        sudo ln -sf "/usr/local/bin/python${PYTHON_MAJOR_VERSION}" /usr/bin/python
        sudo ln -sf /usr/local/bin/pip3 /usr/bin/pip3

        read -p "*** prep-install.sh ansible install , Press to continue.. " -n 1 -r
        sudo apk add py3-passlib
        sudo apk add ansible
        ansible-galaxy collection install community.general
    elif [[ "$distro_type" == "fedora" ]] ; then
        sudo dnf install ansible -y
        ansible-galaxy collection install community.general
    fi
}

profile_path=$1
source $profile_path
echo "###### Prepinstall.sh, reading profile  $profile_path ....."
echo "###### Preparing instance, type  $distro_type , upgrade true/false? $upgrade....."

# read -p "*** Prelim installs for $distro_type, Press to continue.. " -n 1 -r
if [[ "$upgrade" == "true" ]] ; then
    echo "###### Upgrade distro $distro_type ....."
    upgrade
else 
    echo "###### Skipping $distro_type upgrade ....."
fi

exit

