sudo_pass=$1
source ../ubuntu-variables.sh
install_log="$source_base/$distro_name-install.txt"
echo "##    Setting up Helm..."  >> $install_log 2>&1
cd $temp_folder
curl -O "https://get.helm.sh/helm-v3.7.2-linux-amd64.tar.gz" 
tar xvzf helm-v3.7.2-linux-amd64.tar.gz
echo $sudo_pass | sudo -S  mv ./linux-amd64/helm /usr/local/bin

helm plugin install https://github.com/hypnoglow/helm-s3.git
#helm repo add aa-charts s3://aa-helm-charts
#helm search aa-charts
#helm list