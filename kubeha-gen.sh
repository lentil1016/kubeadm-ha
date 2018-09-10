#/bin/bash
if [ -f ./cluster-info ]; then
	source ./cluster-info 
	else
	echo -n "Enter the IP address of master-01: "
	read CP0_IP
	echo -n "Enter the Hostname of master-01: "
	read CP0_HOSTNAME
	echo -n "Enter the IP address of master-02: "
	read CP1_IP
	echo -n "Enter the Hostname of master-02: "
	read CP1_HOSTNAME
	echo -n "Enter the IP address of master-03: "
	read CP2_IP
	echo -n "Enter the Hostname of master-03: "
	read CP2_HOSTNAME
	echo -n "Enter the VIP: "
	read VIP
fi

echo """
cluster-info:
  master-01:        ${CP0_IP}
                    ${CP0_HOSTNAME}
  master-02:        ${CP1_IP}
                    ${CP1_HOSTNAME}
  master-02:        ${CP2_IP}
                    ${CP2_HOSTNAME}
  VIP:              ${VIP}
"""
echo -n 'Please print "yes" to continue or "no" to cancle: '
read AGREE
while [ "${AGREE}" != "yes" ]; do
	if [ "${AGREE}" == "no" ]; then
		exit 0;
	else
		echo -n 'Please print "yes" to continue or "no" to cancle: '
	fi
done

HOSTS=(${CP0_HOSTNAME} ${CP1_HOSTNAME} ${CP2_HOSTNAME})
IPS=(${CP0_IP} ${CP1_IP} ${CP2_IP})

for index in 0 1 2; do
  host=${HOSTS[${index}]}
  ssh ${host} "
    kubeadm reset -f
    rm -rf /etc/kubernetes/pki/"
done

mkdir -p ~/ikube

echo """
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.0
apiServerCertSANs:
- ${CP0_IP}
- ${CP1_IP}
- ${CP2_IP}
- ${CP0_HOSTNAME}
- ${CP1_HOSTNAME}
- ${CP2_HOSTNAME}
- ${VIP}
etcd:
  local:
    extraArgs:
      listen-client-urls: \"https://127.0.0.1:2379,https://${CP0_IP}:2379\"
      advertise-client-urls: \"https://${CP0_IP}:2379\"
      listen-peer-urls: \"https://${CP0_IP}:2380\"
      initial-advertise-peer-urls: \"https://${CP0_IP}:2380\"
      initial-cluster: \"${CP0_HOSTNAME}=https://${CP0_IP}:2380\"
    serverCertSANs:
      - ${CP0_HOSTNAME}
      - ${CP0_IP}
    peerCertSANs:
      - ${CP0_HOSTNAME}
      - ${CP0_IP}
networking:
  # This CIDR is a Calico default. Substitute or remove for your CNI provider.
  podSubnet: \"172.168.0.0/16\"
""" > ~/ikube/kubeadm-config-m0.yaml

echo """
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.0
apiServerCertSANs:
- ${CP0_IP}
- ${CP1_IP}
- ${CP2_IP}
- ${CP0_HOSTNAME}
- ${CP1_HOSTNAME}
- ${CP2_HOSTNAME}
- ${VIP}
etcd:
  local:
    extraArgs:
      listen-client-urls: \"https://127.0.0.1:2379,https://${CP1_IP}:2379\"
      advertise-client-urls: \"https://${CP1_IP}:2379\"
      listen-peer-urls: \"https://${CP1_IP}:2380\"
      initial-advertise-peer-urls: \"https://${CP1_IP}:2380\"
      initial-cluster: \"${CP0_HOSTNAME}=https://${CP0_IP}:2380,${CP1_HOSTNAME}=https://${CP1_IP}:2380\"
      initial-cluster-state: \"existing\"
    serverCertSANs:
      - ${CP1_HOSTNAME}
      - ${CP1_IP}
    peerCertSANs:
      - ${CP1_HOSTNAME}
      - ${CP1_IP}
networking:
  # This CIDR is a Calico default. Substitute or remove for your CNI provider.
  podSubnet: \"172.168.0.0/16\"
""" > ~/ikube/kubeadm-config-m1.yaml

echo """
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.0
apiServerCertSANs:
- ${CP0_IP}
- ${CP1_IP}
- ${CP2_IP}
- ${CP0_HOSTNAME}
- ${CP1_HOSTNAME}
- ${CP2_HOSTNAME}
- ${VIP}
etcd:
  local:
    extraArgs:
      listen-client-urls: \"https://127.0.0.1:2379,https://${CP2_IP}:2379\"
      advertise-client-urls: \"https://${CP2_IP}:2379\"
      listen-peer-urls: \"https://${CP2_IP}:2380\"
      initial-advertise-peer-urls: \"https://${CP2_IP}:2380\"
      initial-cluster: \"${CP0_HOSTNAME}=https://${CP0_IP}:2380,${CP1_HOSTNAME}=https://${CP1_IP}:2380,${CP2_HOSTNAME}=https://${CP2_IP}:2380\"
      initial-cluster-state: \"existing\"
    serverCertSANs:
      - ${CP2_HOSTNAME}
      - ${CP2_IP}
    peerCertSANs:
      - ${CP2_HOSTNAME}
      - ${CP2_IP}
networking:
  # This CIDR is a Calico default. Substitute or remove for your CNI provider.
  podSubnet: \"172.168.0.0/16\"
""" > ~/ikube/kubeadm-config-m2.yaml


for index in 0 1 2; do
  host=${HOSTS[${index}]}
  scp ~/ikube/kubeadm-config-m${index}.yaml ${host}:/etc/kubernetes/kubeadm-config.yaml
done

kubeadm init --config /etc/kubernetes/kubeadm-config.yaml
mkdir -p $HOME/.kube
cp -f /etc/kubernetes/admin.conf ${HOME}/.kube/config

ETCD=`kubectl get pods -n kube-system 2>&1|grep etcd|awk '{print $3}'`
echo "Waiting for etcd bootup..."
while [ "${ETCD}" != "Running" ]; do
  sleep 1
  ETCD=`kubectl get pods -n kube-system 2>&1|grep etcd|awk '{print $3}'`
done

for index in 1 2; do
  host=${HOSTS[${index}]}
  ip=${IPS[${index}]}
  ssh $host "mkdir -p /etc/kubernetes/pki/etcd"
  scp /etc/kubernetes/pki/ca.crt $host:/etc/kubernetes/pki/ca.crt
  scp /etc/kubernetes/pki/ca.key $host:/etc/kubernetes/pki/ca.key
  scp /etc/kubernetes/pki/sa.key $host:/etc/kubernetes/pki/sa.key
  scp /etc/kubernetes/pki/sa.pub $host:/etc/kubernetes/pki/sa.pub
  scp /etc/kubernetes/pki/front-proxy-ca.crt $host:/etc/kubernetes/pki/front-proxy-ca.crt
  scp /etc/kubernetes/pki/front-proxy-ca.key $host:/etc/kubernetes/pki/front-proxy-ca.key
  scp /etc/kubernetes/pki/etcd/ca.crt $host:/etc/kubernetes/pki/etcd/ca.crt
  scp /etc/kubernetes/pki/etcd/ca.key $host:/etc/kubernetes/pki/etcd/ca.key
  scp /etc/kubernetes/admin.conf $host:/etc/kubernetes/admin.conf

  kubectl exec \
    -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl \
    --ca-file /etc/kubernetes/pki/etcd/ca.crt \
    --cert-file /etc/kubernetes/pki/etcd/peer.crt \
    --key-file /etc/kubernetes/pki/etcd/peer.key \
    --endpoints=https://${CP0_IP}:2379 \
    member add ${host} https://${ip}:2380

  ssh ${host} "
    kubeadm alpha phase certs all --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase kubeconfig controller-manager --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase kubeconfig scheduler --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase kubelet config write-to-disk --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase kubelet write-env-file --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase kubeconfig kubelet --config /etc/kubernetes/kubeadm-config.yaml
    systemctl restart kubelet
    kubeadm alpha phase etcd local --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase kubeconfig all --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase controlplane all --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase mark-master --config /etc/kubernetes/kubeadm-config.yaml"
done

kubectl apply -f https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/master/calico/rbac.yaml
kubectl apply -f https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/master/calico/calico.yaml

for index in 0 1 2; do
  host=${HOSTS[${index}]}
  ssh ${host} "sed -i 's/etcd-servers=https:\/\/127.0.0.1:2379/etcd-servers=https:\/\/${CP0_IP}:2379,https:\/\/${CP1_IP}:2379,https:\/\/${CP2_IP}:2379/g' /etc/kubernetes/manifests/kube-apiserver.yaml"
done

POD_UNREADY=`kubectl get pods -n kube-system 2>&1|awk '{print $3}'|grep -vE 'Running|STATUS'`
NODE_UNREADY=`kubectl get nodes 2>&1|awk '{print $2}'|grep -vE 'Ready|STATUS'`
while [ "${POD_UNREADY}" != "" -o "${NODE_UNREADY}" != "" ]; do
  sleep 1
  POD_UNREADY=`kubectl get pods -n kube-system 2>&1|awk '{print $3}'|grep -vE 'Running|STATUS'`
  NODE_UNREADY=`kubectl get nodes 2>&1|awk '{print $2}'|grep -vE 'Ready|STATUS'`
done

echo

kubectl get cs
kubectl get nodes
kubectl get pods -n kube-system
echo """
join command:
  `kubeadm token create --print-join-command|sed "s/${CP0_IP}/${VIP}/g"`"""
