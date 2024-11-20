#https://docs.docker.com/engine/install/ubuntu/
#https://docs.docker.com/engine/install/linux-postinstall/
#https://www.baeldung.com/ops/docker-private-registry
#run docker ps to see if the registry is up and running
#run /usr/bin/dockerd to debug startup issues manually
#if error about docker not running, sudo service docker start
sudo_pass=$1

# docker run hello-world

#setup private registry
sudo  mkdir -p /etc/docker

echo "{\"insecure-registries\":[\"localhost:5000\"]}" | sudo  tee  /etc/docker/daemon.json

sudo systemctl daemon-reload
sudo systemctl restart docker
sudo docker pull registry
sudo docker run -itd -p 5000:5000 --name snarasim-registry registry
