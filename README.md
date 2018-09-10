# install

``` shell
# 创建集群信息文件
$ cat ./cluster-info
CP0_IP=10.130.29.80
CP0_HOSTNAME=centos-7-x86-64-29-80
CP1_IP=10.130.29.81
CP1_HOSTNAME=centos-7-x86-64-29-81
CP2_IP=10.130.29.82
CP2_HOSTNAME=centos-7-x86-64-29-82
VIP=10.130.29.83
NET_IF=ens32

$ bash -c "$(curl -fsSL https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/master/kubeha-gen.sh)"
```

## generate join command

``` shell
kubeadm token create --print-join-command|sed 's/${LOCAL_IP}/${VIP}/g'
```
