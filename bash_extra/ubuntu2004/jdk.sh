sudo_pass=$1
source ../ubuntu-variables.sh

echo $sudo_pass | sudo -S apt install openjdk-11-jdk  -y
echo $sudo_pass | sudo -S apt install openjdk-8-jdk  -y
#echo $sudo_pass | sudo -S echo "JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/" >> /etc/environment
echo $sudo_pass | sudo -S echo 'export PATH=/usr/lib/jvm/java-11-openjdk-amd64/bin/:$PATH' >> $HOME/.bashrc_custom 


