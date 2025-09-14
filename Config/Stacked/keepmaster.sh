#!/bin/bash

### Add MetalLB (Load Balancing in a VMs Cluster)
helm repo add metallb https://metallb.github.io/metallb;
helm install metallb metallb/metallb --set crds.validationFailurePolicy=Ignore -n metallb-system --create-namespace;

### Install NGINX Ingress Controller
VER_NGINX_INGRESS_CONTROLLER=$(curl --silent -qI https://github.com/kubernetes/ingress-nginx/releases/latest/download/ |  awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/$VER_NGINX_INGRESS_CONTROLLER/deploy/static/provider/cloud/deploy.yaml;

### Install Kgateway Gateway API 
VER_KGATEWAY=$(curl --silent -qI https://github.com/kubernetes-sigs/gateway-api/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$VER_KGATEWAY/standard-install.yaml;
VER_KGATEWAY_HELM=$(curl --silent -qI https://github.com/kgateway-dev/kgateway/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
helm upgrade -i --create-namespace --namespace kgateway-system --version $VER_KGATEWAY_HELM kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds;
helm upgrade -i --namespace kgateway-system --version $VER_KGATEWAY_HELM kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway;
