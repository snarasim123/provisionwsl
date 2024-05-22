#!/usr/bin/env bash
source ./variables.sh

upgrade() {
sudo apt update -y
sudo apt upgrade -y
}

setup-ssh () {
    echo "#### Setting up ssh keys ."
    cd $HOME

    if [ ! -f "$HOME/.ssh/id_rsa" ]; then
        eval `ssh-agent -s`
        ssh-keygen -t rsa -b 4096 -N ''  -f $HOME/.ssh/id_rsa <<< y
        ssh-add $HOME/.ssh/id_rsa
    fi
    echo "#### Done Setting up ssh keys. "
}

setup-user () {
    echo "#### Setting up root user and default user '$default_user' for distro '$distro_name'. "
    echo " export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/lib/wsl/lib" > $HOME/.bashrc
    source $HOME/.bashrc

    if id "$default_user" >/dev/null 2>&1; then
        echo "User $default_user already exists."
    else
        echo 'Creating user $default_user.'
        useradd -m "$default_user"
    fi
    sleep 5
    echo "$default_user":"$default_user" | chpasswd
    echo "$default_user ALL=(ALL) NOPASSWD: ALL"  >> /etc/sudoers

    # if ! grep  '[boot]' "/etc/wsl.conf"; then
    echo 'Add [boot] to /etc/wsl.conf.'
    printf '%s\n' '[boot]' > /etc/wsl.conf
    printf '%s\n' 'systemd=true' >> /etc/wsl.conf
    # fi

    # if ! grep  '[user]' "/etc/wsl.conf"; then
    echo 'Add [user] to /etc/wsl.conf.'
    printf '%s\n' '[user]' >> /etc/wsl.conf
    printf '%s\n' "default=$default_user" >> /etc/wsl.conf
    # fi

    chsh -s /bin/bash root
    chsh -s /bin/bash $default_user
    echo " export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/lib/wsl/lib" > /home/$default_user/.bashrc

    echo "#### Done setting up default user '$default_user' with password '$default_user'."
}


# read -p "*** Press to continue.. " -n 1 -r
upgrade
setup-user
exit
