#/bin/bash

openssl req -newkey rsa:4096 -nodes -config ./openssl.cnf -days 3650 -x509 -out tls.crt -keyout tls.key
kubectl delete secret -n kube-system ssl
kubectl create -n kube-system secret tls ssl --cert tls.crt --key tls.key
rm -f ./tls.crt ./tls.key

for namespace in `kubectl get namespace|grep -vE '(kube-system|kube-public|NAME|default)'|awk '{print $1}'`
do
	kubectl get -n kube-system secret ssl -o yaml | grep -vE '(creationTimestamp|resourceVersion|selfLink|uid)'|sed "s/kube-system/${namespace}/g" > ssl.yaml
	kubectl apply -f ssl.yaml
	rm ssl.yaml
done
