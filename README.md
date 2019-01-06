# install
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2FLentil1016%2Fkubeadm-ha.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2FLentil1016%2Fkubeadm-ha?ref=badge_shield) ![](https://img.shields.io/badge/Dist-Centos7-blue.svg) ![](https://img.shields.io/badge/Dist-Fedora27-yellow.svg) ![](https://img.shields.io/badge/DNS-CoreDNS-brightgreen.svg)  ![](https://img.shields.io/badge/Mode-HA-brightgreen.svg)  ![](https://img.shields.io/badge/Proxy-IPVS-brightgreen.svg)  ![](https://img.shields.io/badge/Net-Calico-brightgreen.svg)

``` shell
# 创建集群信息文件
$ cat ./cluster-info
CP0_IP=10.130.29.80
CP1_IP=10.130.29.81
CP2_IP=10.130.29.82
VIP=10.130.29.83
NET_IF=ens32
CIDR=10.244.0.0/16

$ bash -c "$(curl -fsSL https://k8s.lentil1016.cn)"
```

## Generate join command

``` shell
kubeadm token create --print-join-command
```

## The following images could be used for deploying:

```
k8s.gcr.io/coredns:1.2.6
k8s.gcr.io/etcd:3.2.24
k8s.gcr.io/kube-apiserver:v1.13.0
k8s.gcr.io/kube-controller-manager:v1.13.0
k8s.gcr.io/kube-scheduler:v1.13.0
k8s.gcr.io/kube-proxy:v1.13.0

k8s.gcr.io/kubernetes-dashboard-amd64:v1.10.0
k8s.gcr.io/metrics-server-amd64:v0.3.1
k8s.gcr.io/addon-resizer:1.8.4

gcr.io/kubernetes-helm/tiller:v2.12.0

quay.io/calico/cni:v3.3.2
quay.io/calico/node:v3.3.2

quay.io/coreos/addon-resizer:1.0
quay.io/coreos/configmap-reload:v0.0.1

quay.io/coreos/k8s-prometheus-adapter-amd64:v0.4.1
quay.io/coreos/kube-rbac-proxy:v0.4.0
quay.io/coreos/kube-state-metrics:v1.4.0
quay.io/coreos/prometheus-config-reloader:v0.26.0
quay.io/coreos/prometheus-operator:v0.26.0

quay.io/prometheus/alertmanager:v0.15.3
quay.io/prometheus/node-exporter:v0.16.0
quay.io/prometheus/prometheus:v2.5.0

ceph/ceph:v13
grafana/grafana:5.2.4
rook/ceph:master
traefik:1.7.5
```

## License
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2FLentil1016%2Fkubeadm-ha.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2FLentil1016%2Fkubeadm-ha?ref=badge_large)
