#/bin/bash

function check_parm()
{
  if [ "${2}" == "" ]; then
    echo -n "${1}"
    return 1
  else
    return 0
  fi
}

if [ -f ./cluster-info ]; then
	source ./cluster-info 
fi

check_parm "Enter the IP address of master-01: " ${CP0_IP} 
if [ $? -eq 1 ]; then
	read CP0_IP
fi
check_parm "Enter the Hostname of master-01: " ${CP0_HOSTNAME}
if [ $? -eq 1 ]; then
	read CP0_HOSTNAME
fi
check_parm "Enter the IP address of master-02: " ${CP1_IP}
if [ $? -eq 1 ]; then
	read CP1_IP
fi
check_parm "Enter the Hostname of master-02: " ${CP1_HOSTNAME}
if [ $? -eq 1 ]; then
	read CP1_HOSTNAME
fi
check_parm "Enter the IP address of master-03: " ${CP2_IP}
if [ $? -eq 1 ]; then
	read CP2_IP
fi
check_parm "Enter the Hostname of master-03: " ${CP2_HOSTNAME}
if [ $? -eq 1 ]; then
	read CP2_HOSTNAME
fi
check_parm "Enter the VIP: " ${VIP}
if [ $? -eq 1 ]; then
	read VIP
fi
check_parm "Enter the Net Interface: " ${NET_IF}
if [ $? -eq 1 ]; then
	read NET_IF
fi
check_parm "Enter the cluster CIDR: " ${CIDR}
if [ $? -eq 1 ]; then
	read CIDR
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
  Net Interface:    ${NET_IF}
  CIDR:             ${CIDR}
"""
echo -n 'Please print "yes" to continue or "no" to cancle: '
read AGREE
while [ "${AGREE}" != "yes" ]; do
	if [ "${AGREE}" == "no" ]; then
		exit 0;
	else
		echo -n 'Please print "yes" to continue or "no" to cancle: '
		read AGREE
	fi
done

mkdir -p ~/ikube/tls

HOSTS=(${CP0_HOSTNAME} ${CP1_HOSTNAME} ${CP2_HOSTNAME})
IPS=(${CP0_IP} ${CP1_IP} ${CP2_IP})

PRIORITY=(100 50 30)
STATE=("MASTER" "BACKUP" "BACKUP")
HEALTH_CHECK=""
for index in 0 1 2; do
  HEALTH_CHECK=${HEALTH_CHECK}"""
    real_server ${IPS[$index]} 6443 {
        weight 1
        SSL_GET {
            url {
              path /healthz
              status_code 200
            }
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3
        }
    }
"""
done

for index in 0 1 2; do
  host=${HOSTS[${index}]}
  ip=${IPS[${index}]}
  echo """
global_defs {
   router_id LVS_DEVEL
}

vrrp_instance VI_1 {
    state ${STATE[${index}]}
    interface ${NET_IF}
    virtual_router_id 80
    priority ${PRIORITY[${index}]}
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass just0kk
    }
    virtual_ipaddress {
        ${VIP}
    }
}

virtual_server ${VIP} 6443 {
    delay_loop 6
    lb_algo loadbalance
    lb_kind DR
    nat_mask 255.255.255.0
    persistence_timeout 0
    protocol TCP

${HEALTH_CHECK}
}
""" > ~/ikube/keepalived-${index}.conf
  scp ~/ikube/keepalived-${index}.conf ${host}:/etc/keepalived/keepalived.conf

  ssh ${host} "
    systemctl restart keepalived"

  if [ ${index} -ne 0 ]; then
    ETCD_MEMBER="${ETCD_MEMBER},"
    ETCD_STATUS="existing"
  else
    ETCD_MEMBER=""
    ETCD_STATUS="new"
  fi
  ETCD_MEMBER="${ETCD_MEMBER}${host}=https://${ip}:2380"

  echo """
kind: InitConfiguration
apiVersion: kubeadm.k8s.io/v1alpha3
---
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
kubeProxy:
  config:
    mode: ipvs
etcd:
  local:
    extraArgs:
      listen-client-urls: https://127.0.0.1:2379,https://${ip}:2379
      advertise-client-urls: https://${ip}:2379
      listen-peer-urls: https://${ip}:2380
      initial-advertise-peer-urls: https://${ip}:2380
      initial-cluster: ${ETCD_MEMBER}
      initial-cluster-state: ${ETCD_STATUS}
    serverCertSANs:
      - ${host}
      - ${ip}
    peerCertSANs:
      - ${host}
      - ${ip}
networking:
  # This CIDR is a Calico default. Substitute or remove for your CNI provider.
  podSubnet: ${CIDR}
""" > ~/ikube/kubeadm-config-m${index}.yaml

  scp ~/ikube/kubeadm-config-m${index}.yaml ${host}:/etc/kubernetes/kubeadm-config.yaml
done

pushd /etc/kubernetes;
    rm admin.conf controller-manager.conf kubelet.conf scheduler.conf manifests/etcd.yaml pki/apiserver.crt pki/apiserver.key pki/etcd/server.crt pki/etcd/server.key pki/etcd/peer.crt pki/etcd/peer.key
    kubeadm alpha phase certs apiserver --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase certs etcd-server --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase certs etcd-peer --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase etcd local --config /etc/kubernetes/kubeadm-config.yaml 
    kubeadm alpha phase kubeconfig all --config /etc/kubernetes/kubeadm-config.yaml 
    echo "Restarting etcd/apiserver/controller/scheduler containers."
    docker ps|grep -E 'k8s_kube-scheduler|k8s_kube-controller-manager|k8s_kube-apiserver|k8s_etcd'|awk '{print $1}'|xargs -i docker rm -f {} > /dev/null
    systemctl restart kubelet
    cp /etc/kubernetes/admin.conf ~/.kube/config
popd

ETCD=`kubectl get pods -n kube-system 2>&1|grep etcd|awk '{print $3}'`
echo "Waiting for etcd bootup..."
while [ "${ETCD}" != "Running" ]; do
  sleep 1
  ETCD=`kubectl get pods -n kube-system 2>&1|grep etcd|awk '{print $3}'`
done

ETCD_MASTER_ID=`kubectl exec \
  -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl \
  --ca-file /etc/kubernetes/pki/etcd/ca.crt \
  --cert-file /etc/kubernetes/pki/etcd/peer.crt \
  --key-file /etc/kubernetes/pki/etcd/peer.key \
  --endpoints=https://${CP0_IP}:2379 \
  member list | awk -F ':' '{print $1}'`

echo "Updating the PeerUrl of ETCD master [${ETCD_MASTER_ID}]"
kubectl exec \
  -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl \
  --ca-file /etc/kubernetes/pki/etcd/ca.crt \
  --cert-file /etc/kubernetes/pki/etcd/peer.crt \
  --key-file /etc/kubernetes/pki/etcd/peer.key \
  --endpoints=https://${CP0_IP}:2379 \
  member update ${ETCD_MASTER_ID} https://${CP0_IP}:2380

kubectl exec \
  -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl \
  --ca-file /etc/kubernetes/pki/etcd/ca.crt \
  --cert-file /etc/kubernetes/pki/etcd/peer.crt \
  --key-file /etc/kubernetes/pki/etcd/peer.key \
  --endpoints=https://${CP0_IP}:2379 \
  member list

for index in 1 2; do
  host=${HOSTS[${index}]}
  ip=${IPS[${index}]}
  ssh $host "mkdir -p /etc/kubernetes/pki/etcd; mkdir -p ~/.kube"
  scp /etc/kubernetes/pki/ca.crt $host:/etc/kubernetes/pki/ca.crt
  scp /etc/kubernetes/pki/ca.key $host:/etc/kubernetes/pki/ca.key
  scp /etc/kubernetes/pki/sa.key $host:/etc/kubernetes/pki/sa.key
  scp /etc/kubernetes/pki/sa.pub $host:/etc/kubernetes/pki/sa.pub
  scp /etc/kubernetes/pki/front-proxy-ca.crt $host:/etc/kubernetes/pki/front-proxy-ca.crt
  scp /etc/kubernetes/pki/front-proxy-ca.key $host:/etc/kubernetes/pki/front-proxy-ca.key
  scp /etc/kubernetes/pki/etcd/ca.crt $host:/etc/kubernetes/pki/etcd/ca.crt
  scp /etc/kubernetes/pki/etcd/ca.key $host:/etc/kubernetes/pki/etcd/ca.key
  scp /etc/kubernetes/admin.conf $host:/etc/kubernetes/admin.conf
  scp /etc/kubernetes/admin.conf $host:~/.kube/config

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

for index in 0 1 2; do
  host=${HOSTS[${index}]}
  ip=${IPS[${index}]}
  ssh ${host} "sed -i 's/etcd-servers=https:\/\/127.0.0.1:2379/etcd-servers=https:\/\/${CP0_IP}:2379,https:\/\/${CP1_IP}:2379,https:\/\/${CP2_IP}:2379/g' /etc/kubernetes/manifests/kube-apiserver.yaml"
  ssh ${host} "sed -i 's/${CP0_IP}/${VIP}/g' ~/.kube/config"
  ssh ${host} "sed -i 's/${ip}/${VIP}/g' /etc/kubernetes/kubelet.conf; systemctl restart kubelet"
done

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
