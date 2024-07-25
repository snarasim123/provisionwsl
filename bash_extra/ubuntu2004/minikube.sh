#https://bell-sw.com/announcements/2022/09/14/how-to-create-a-single-node-kubernetes-cluster/
sudo_pass=$1

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
echo $sudo_pass | sudo -S  install minikube-linux-amd64 /usr/local/bin/minikube
# sudo mkdir -p /usr/local/bin/
# sudo install minikube /usr/local/bin/
minikube config set driver docker
minikube start --vm-driver=docker
minikube status
minikube stop

