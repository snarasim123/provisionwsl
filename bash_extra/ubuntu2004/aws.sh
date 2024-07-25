sudo_pass=$1
source ../ubuntu-variables.sh
install_log="$source_base/$distro_name-install.txt"

echo "#     Installing aws cli"  >> $install_log 2>&1

cd $temp_folder
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
echo $sudo_pass | sudo -S  ./aws/install 
