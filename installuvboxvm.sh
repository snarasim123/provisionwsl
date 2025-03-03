#!/bin/bash

# Variables
IMAGE_URL="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.ova"
IMAGE_NAME="ubuntu-focal"
VM_NAME="Ubuntu_Focal_Server"
DOWNLOAD_DIR="$HOME/Downloads"
OVA_FILE="$DOWNLOAD_DIR/$(basename $IMAGE_URL)"

# Function to download the Ubuntu VirtualBox image
download_image() {
    echo "Downloading Ubuntu VirtualBox image..."
    wget -P "$DOWNLOAD_DIR" "$IMAGE_URL"
    if [ $? -ne 0 ]; then
        echo "Failed to download the image."
        exit 1
    fi
    echo "Download complete."
}

# Function to import the OVA file into VirtualBox
import_image() {
    echo "Importing the OVA file into VirtualBox..."
    VBoxManage import "$OVA_FILE" --vsys 0 --vmname "$VM_NAME"
    if [ $? -ne 0 ]; then
        echo "Failed to import the OVA file."
        exit 1
    fi
    echo "Import complete."
}

# Function to start the VirtualBox VM
start_vm() {
    echo "Starting the VirtualBox VM..."
    VBoxManage startvm "$VM_NAME" --type headless
    if [ $? -ne 0 ]; then
        echo "Failed to start the VM."
        exit 1
    fi
    echo "VM started in headless mode."
}

# Main script execution
echo "Setting up Ubuntu VirtualBox image..."

# Step 1: Download the OVA file
download_image

# Step 2: Import the OVA file into VirtualBox
import_image

# Step 3: Start the VM
start_vm

echo "Ubuntu VirtualBox image setup complete."