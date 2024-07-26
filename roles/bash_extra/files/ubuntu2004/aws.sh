sudo_pass=$1
source ../ubuntu-variables.sh

cd $temp_folder
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
echo $sudo_pass | sudo -S  ./aws/install 
