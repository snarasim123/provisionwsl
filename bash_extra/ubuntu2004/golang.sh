sudo_pass=$1
source ../ubuntu-variables.sh
install_log="$source_base/$distro_name-install.txt"
echo "##    Setting up golang..."  >> $install_log 2>&1
cd $temp_folder
wget https://go.dev/dl/go1.17.13.linux-amd64.tar.gz
tar -xvf go1.17.13.linux-amd64.tar.gz
echo $sudo_pass | sudo -S  mv go /usr/local  
mkdir -p $HOME/go
export GOPATH=$HOME/go
export GOROOT=/usr/local/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
