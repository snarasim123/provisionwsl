#!/bin/bash

# Variables
VM_NAME="MyVM"
OS_TYPE="Ubuntu_64"
MEMORY_SIZE="2048" # in MB
VRAM_SIZE="128" # in MB
HDD_SIZE="20480" # in MB
ISO_PATH="/path/to/your/iso/file.iso"
SSH_USER="your_ssh_username"
SSH_KEY="/path/to/your/ssh/key"

# Create the VM
echo "Creating VM..."
VBoxManage createvm --name "$VM_NAME" --ostype "$OS_TYPE" --register

# Configure the VM
echo "Configuring VM..."
VBoxManage modifyvm "$VM_NAME" --memory "$MEMORY_SIZE" --vram "$VRAM_SIZE" --nic1 nat --cpus 2

# Create a virtual hard disk
echo "Creating virtual hard disk..."
VBoxManage createhd --filename "$VM_NAME.vdi" --size "$HDD_SIZE" --format VDI

# Attach the hard disk to the VM
echo "Attaching hard disk to VM..."
VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci
VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$VM_NAME.vdi"

# Attach the ISO file to the VM
echo "Attaching ISO to VM..."
VBoxManage storagectl "$VM_NAME" --name "IDE Controller" --add ide
VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$ISO_PATH"

# Configure boot order
echo "Setting boot order..."
VBoxManage modifyvm "$VM_NAME" --boot1 dvd --boot2 disk --boot3 none --boot4 none

# Start the VM
echo "Starting VM..."
VBoxManage startvm "$VM_NAME" --type headless

# Wait for the VM to boot and get the IP address
echo "Waiting for VM to boot..."
sleep 60

# Get the VM's IP address
VM_IP=$(VBoxManage guestproperty get "$VM_NAME" "/VirtualBox/GuestInfo/Net/0/V4/IP" | awk '{print $2}')
echo "VM IP Address: $VM_IP"

# SSH into the VM
echo "SSHing into the VM..."
ssh -i "$SSH_KEY" "$SSH_USER@$VM_IP"

# End of script
echo "Script completed."