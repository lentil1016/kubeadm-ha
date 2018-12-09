#!/bin/bash

kubeadm init --kubernetes-version=v1.13.0 --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
rm -f $HOME/.kube/config
cp -f /etc/kubernetes/admin.conf ${HOME}/.kube/config

kubectl apply -f https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/1.13.0/calico/rbac.yaml
curl -fsSL https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/1.13.1/calico/calico.yaml | sed "s!8.8.8.8!${CP0_IP}!g" | sed "s!10.244.0.0/16!${CIDR}!g" | kubectl apply -f -

echo "Cluster create finished."

mkdir -p ~/ikube/tls
echo """
[req] 
distinguished_name = req_distinguished_name
prompt = yes
[ req_distinguished_name  ]
countryName                     = Country Name (2 letter code)
countryName_value               = CN
stateOrProvinceName             = State or Province Name (full name)
stateOrProvinceName_value       = Beijing
localityName                    = Locality Name (eg, city)
localityName_value              = Haidian
organizationName                = Organization Name (eg, company)
organizationName_value          = Channelsoft
organizationalUnitName          = Organizational Unit Name (eg, section)
organizationalUnitName_value    = R & D Department
commonName                      = Common Name (eg, your name or your server\'s hostname)
commonName_value                = *.multi.io
emailAddress                    = Email Address
emailAddress_value              = lentil1016@gmail.com
""" > ~/ikube/tls/openssl.cnf
openssl req -newkey rsa:4096 -nodes -config ~/ikube/tls/openssl.cnf -days 3650 -x509 -out ~/ikube/tls/tls.crt -keyout ~/ikube/tls/tls.key

kubectl create -n kube-system secret tls ssl --cert ~/ikube/tls/tls.crt --key ~/ikube/tls/tls.key
kubectl apply -f https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/1.13.0/plugin/traefik.yaml
kubectl apply -f https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/1.13.0/plugin/metrics.yaml
kubectl apply -f https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/1.13.0/plugin/kubernetes-dashboard.yaml

echo "Plugin install finished."
echo "Waiting for all pods into 'Running' statu. You can press 'Ctrl + c' to terminate this waiting any time you like."
POD_UNREADY=`kubectl get pods -n kube-system 2>&1|awk '{print $3}'|grep -vE 'Running|STATUS'`
NODE_UNREADY=`kubectl get nodes 2>&1|awk '{print $2}'|grep 'NotReady'`
while [ "${POD_UNREADY}" != "" -o "${NODE_UNREADY}" != "" ]; do
  sleep 1
  POD_UNREADY=`kubectl get pods -n kube-system 2>&1|awk '{print $3}'|grep -vE 'Running|STATUS'`
  NODE_UNREADY=`kubectl get nodes 2>&1|awk '{print $2}'|grep 'NotReady'`
done

echo

kubectl get cs
kubectl get nodes
kubectl get pods -n kube-system

echo """
join command:
  `kubeadm token create --print-join-command`"""
