#!/bin/bash

# Function to install VirtualBox on Debian-based systems
install_virtualbox_debian() {
    echo "Installing VirtualBox on Debian-based system..."
    sudo apt-get update
    sudo apt-get install -y virtualbox virtualbox-ext-pack
}

# Function to install VirtualBox on Red Hat-based systems
install_virtualbox_redhat() {
    echo "Installing VirtualBox on Red Hat-based system..."
    sudo dnf install -y VirtualBox
}

# Function to configure VirtualBox
configure_virtualbox() {
    echo "Configuring VirtualBox..."

    # Add the current user to the vboxusers group
    sudo usermod -aG vboxusers $USER

    # Enable USB 2.0 and 3.0 support (requires VirtualBox Extension Pack)
    VBoxManage modifyvm "VM_NAME" --usbehci on
    VBoxManage modifyvm "VM_NAME" --usbxhci on

    echo "VirtualBox configuration complete."
}

# Detect the Linux distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect the Linux distribution."
    exit 1
fi

# Install VirtualBox based on the detected distribution
case $OS in
    ubuntu|debian)
        install_virtualbox_debian
        ;;
    fedora|centos|rhel)
        install_virtualbox_redhat
        ;;
    *)
        echo "Unsupported Linux distribution: $OS"
        exit 1
        ;;
esac

# Configure VirtualBox
configure_virtualbox

echo "VirtualBox installation and configuration complete."