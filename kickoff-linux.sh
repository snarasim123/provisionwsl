#!/bin/bash

# Read arguments
distro_type_param=$1
skip_upgrade_param=$2

# Start timer
start_time=$(date +%s)

# Path to variables file
Path="./variables.sh"

# Source the variables file
source $Path

# Determine distro name and source based on the parameter
case $distro_type_param in
    "ubuntu")
        distro_name=$distro_name_ubuntu
        distro_type="ubuntu"
        ps_distro_source=$ps_distro_source_ubuntu
        ;;
    "fedora")
        distro_name=$distro_name_fedora
        distro_type="fedora"
        ps_distro_source=$ps_distro_source_fedora
        ;;
    "alpine")
        distro_name=$distro_name_alpine
        distro_type="alpine"
        ps_distro_source=$ps_distro_source_alpine
        ;;
    *)
        echo "##### Specify a distro type as param (ubuntu/fedora/alpine)"
        exit 1
        ;;
esac

# Set install name and directory
install_name=$distro_name
ps_install_dir="$ps_install_dir/$distro_name"

# Print spinup params
echo -e "#####  Spinup params

          distro type       : $distro_type
          distro_name       : $install_name
          distro source     : $ps_distro_source
          install location  : $ps_install_dir

#####"

# Check if the instance already exists
if wsl -l | grep -q "$install_name"; then
    echo "##### Instance exists. Skip creating instance with name $install_name..."
else
    echo "##### Creating new instance with name $install_name Step 1..."
    mkdir -p "$ps_install_dir"
    wsl --import "$install_name" "$ps_install_dir" "$ps_distro_source"
fi

echo "##### Restarting instance $install_name..."
wsl --terminate "$install_name"

echo "##### Preliminary setup $install_name Step 2..."
wsl -d "$install_name" ./prep-install.sh "$distro_type" "$skip_upgrade_param" -u root

echo "##### Main setup $install_name Step 3..."
wsl -d "$install_name" ./install.sh "$distro_type" -u root

echo "##### Restarting instance $install_name..."
wsl --terminate "$install_name"

echo "##### Instance $install_name ready."
wsl -d "$install_name" lsb_release -d
wsl -d "$install_name" ls /

# Calculate and print elapsed time
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))
elapsed_hours=$((elapsed_time / 3600))
elapsed_minutes=$(( (elapsed_time % 3600) / 60 ))

echo "##### RunTime ${elapsed_hours} Hours : ${elapsed_minutes} Mins..."