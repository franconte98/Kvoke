#!/bin/bash

### Add MetalLB (Load Balancing in a VMs Cluster)
helm repo add metallb https://metallb.github.io/metallb;
kubectl create namespace metallb-system;
helm install metallb metallb/metallb --set crds.validationFailurePolicy=Ignore -n metallb-system;

### Install NGINX Ingress Controller
VER_NGINX_INGRESS_CONTROLLER=$(curl --silent -qI https://github.com/kubernetes/ingress-nginx/releases/latest/download/ |  awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/$VER_NGINX_INGRESS_CONTROLLER/deploy/static/provider/cloud/deploy.yaml;

### Install Kgateway Gateway API 
VER_KGATEWAY=$(curl --silent -qI https://github.com/kubernetes-sigs/gateway-api/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$VER_KGATEWAY/standard-install.yaml;
VER_KGATEWAY_HELM=$(curl --silent -qI https://github.com/kgateway-dev/kgateway/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
helm upgrade -i --create-namespace --namespace kgateway-system --version $VER_KGATEWAY_HELM kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds;
helm upgrade -i --namespace kgateway-system --version $VER_KGATEWAY_HELM kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway;

### Add k9s (Complete Dashboard accessible from Command Line)
sudo snap install k9s;
sudo ln -s /snap/k9s/current/bin/k9s /snap/bin/;

### Increase the number of lines to be logged in k9s
sed -i 's/tail.*/tail: 1000/' ~/.config/k9s/config.yml;
sed -i 's/buffer.*/buffer: 500/' ~/.config/k9s/config.yml;

### Install Weave as a Network Plugin
VER_LATEST_WEAVE=$(curl --silent -qI https://github.com/weaveworks/weave/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
kubectl apply -f https://github.com/weaveworks/weave/releases/download/$VER_LATEST_WEAVE/weave-daemonset-k8s.yaml;