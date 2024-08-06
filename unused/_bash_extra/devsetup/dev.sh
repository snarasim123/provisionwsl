#copy cliBuddy_v0.2.zip file to the local folder first
#signin and export aws creds as env variables
sudo_pass=$1
temp_folder="$HOME/tmp"
today=`date "+%Y%m%d%H%M%S"`

current_folder_aadev=$(pwd)
cp ./cliBuddy_v0.2.zip "$temp_folder"
cd $temp_folder
unzip cliBuddy_v0.2.zip

cd Engineer
dos2unix -b ./AWSconfig  
dos2unix -b ./AWScredentials  
dos2unix -b ./KUBEconfig

cd linux
dos2unix -b ./awsBuddy_v01.sh  
dos2unix -b ./kubeBuddy_v01.sh  
dos2unix -b ./runOnce.sh
echo $sudo_pass | sudo -S  chmod +x ./awsBuddy_v01.sh
echo $sudo_pass | sudo -S  chmod +x ./kubeBuddy_v01.sh
echo $sudo_pass | sudo -S  chmod +x ./runOnce.sh
source ./runOnce.sh
cp ./awsBuddy_v01.sh $HOME/bin
cp ./kubeBuddy_v01.sh $HOME/bin

helm repo add aa-charts s3://aa-helm-charts
helm list

cp -r ./.kube_aws ~
cp -r ./.kube_gcp ~
echo "KUBECONFIG=$HOME/.kube_aws/config" >> $HOME/.bashrc_custom