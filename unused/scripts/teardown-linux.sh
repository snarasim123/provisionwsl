#!/bin/bash

distro_type_param=$1

Path="./variables.sh"
# distro_name=""
source $Path

if [ "$distro_type_param" == "ubuntu" ]; then
    echo "##### distro type ubuntu $distro_type_param"
    distro_name=$distro_name_ubuntu
    distro_type="ubuntu"
    ps_distro_source=$ps_distro_source_ubuntu
    ps_install_dir="$ps_install_dir/$distro_name_ubuntu"
elif [ "$distro_type_param" == "fedora" ]; then
    echo "##### distro type fedora $distro_type_param"
    distro_name=$distro_name_fedora
    distro_type="fedora"
    ps_distro_source=$ps_distro_source_fedora
    ps_install_dir="$ps_install_dir/$distro_name_fedora"
elif [ "$distro_type_param" == "alpine" ]; then
    echo "##### distro type alpine $distro_type_param"
    distro_name=$distro_name_alpine
    distro_type="alpine"
    ps_distro_source=$ps_distro_source_alpine
    ps_install_dir="$ps_install_dir/$ps_distro_source_alpine"
else
    echo "##### Specify a distro type as param (ubuntu/fedora/alpine)"
    exit 1
fi

echo -e "#####  Teardown params

          distro type   : $distro_type
          distro_name   : $distro_name
          distro source : $ps_distro_source

#####   "

i=15
echo "Wait $i Seconds"
while [ $i -gt 0 ]; do
    echo -n "#"
    sleep 1
    i=$((i-1))
done
echo

install_name=$distro_name

echo "##### Teardown  $install_name from dir $ps_install_dir"

match=$(wsl -l | grep -w "$install_name")
if [ -n "$match" ]; then
    echo "##### Instance exists. Tearing down $install_name..."
    wsl --unregister $install_name
    rm -rf $ps_install_dir
else
    echo "##### Instance with name $install_name does not exist. returning..."
fi