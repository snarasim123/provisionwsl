#pre req - $HOME/bin created, added to path
sudo_pass=$1
source ../ubuntu-variables.sh
install_log="$source_base/$distro_name-install.txt"
echo "##    Setting up K8s..."  >> $install_log 2>&1

cd $temp_folder
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.25.6/2023-01-30/bin/linux/amd64/kubectl
chmod +x ./kubectl
cp ./kubectl $HOME/bin/kubectl
rm ./kubectl
mkdir ${HOME}/.kube -p
# echo 'export KUBECONFIG=${HOME}/.kube/config' >> ~/.bash_profile

# k9s
echo "##    Installing k9s..."  >> $install_log 2>&1
cd $temp_folder
wget https://github.com/derailed/k9s/releases/download/v0.27.4/k9s_Linux_amd64.tar.gz
tar -xvf k9s_Linux_amd64.tar.gz
mv ./k9s $HOME/bin

#https://github.com/catppuccin/k9s