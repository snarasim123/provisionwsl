#!/usr/bin/env bash
declare  -a ubuntufiles=("aws.sh"  "helm.sh" "jdk.sh" "k8s.sh" "minikube.sh" )
# "docker.sh" "dockerregistry.sh"   "nvim.sh" "redis.sh" "golang.sh"
cd ~/
mkdir tmp
cd tmp
sudo cp -r /root/code/setup/ansible/bash_extra .
cd ./bash_extra/ubuntu2004
for f in "${ubuntufiles[@]}"; do
      echo "### exec $f"
      source "$f"  
done

  source "/root/code/setup/ansible/bash_extra/devsetup/dev.sh"  