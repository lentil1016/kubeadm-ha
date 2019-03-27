#!/bin/bash

kubeadm reset -f

echo """
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: v1.14.0
networking:
  # This CIDR is a Calico default. Substitute or remove for your CNI provider.
  podSubnet: 192.168.0.0/16
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
""" > /etc/kubernetes/kubeadm-config.yaml

kubeadm init --config /etc/kubernetes/kubeadm-config.yaml
mkdir -p $HOME/.kube
rm -f $HOME/.kube/config
cp -f /etc/kubernetes/admin.conf ${HOME}/.kube/config

kubectl apply -f https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/1.14.0/calico/calico.yaml

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
kubectl apply -f https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/1.14.0/plugin/traefik.yaml
kubectl apply -f https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/1.14.0/plugin/metrics.yaml
kubectl apply -f https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/1.14.0/plugin/kubernetes-dashboard.yaml

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
