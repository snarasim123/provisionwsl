sudo_pass=$1
source ../ubuntu-variables.sh
# install_log="$source_base/$distro_name-install.txt"
# echo "## Setting up Redis..."  >> $install_log 2>&1
#TODO
#https://download.redis.io/releases/
cd $temp_dir
mkdir redis
cd ./redis

wget https://download.redis.io/redis-stable.tar.gz
tar -xzvf redis-stable.tar.gz
cd redis-stable
make

sed -i "s|^databases 16$|databases 128|" ./redis.conf
sed -i "s|^# maxclients 10000$|maxclients 512|" ./redis.conf
sed -i "s|^bind 127.0.0.1 -::1|#bind 127.0.0.1 -::1|"  ./redis.conf
sed -i "s|^bind 127.0.0.1|#bind 127.0.0.1|"  ./redis.conf
sed -i "s|^protected-mode yes|protected-mode no|"  ./redis.conf

echo $sudo_pass | sudo -S make install

cp ./redis.conf $HOME/bin
echo "redis-server $HOME/bin/redis.conf" > $HOME/bin/redis.sh
chmod +x $HOME/bin/redis.sh

cd $temp_dir
rm -rf redis/*
rmdir ./redis