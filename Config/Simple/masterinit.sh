#!/bin/bash

# Initialization based on CRI
case $2 in
    "Docker")
        sudo kubeadm init --upload-certs \
            --control-plane-endpoint="$1:6443" \
            --apiserver-advertise-address="$1" \
            --cri-socket unix:///var/run/cri-dockerd.sock
        ;;
    "Containerd")
        sudo kubeadm init --upload-certs \
            --control-plane-endpoint="$1:6443" \
            --apiserver-advertise-address="$1" \
            --cri-socket unix:///run/containerd/containerd.sock
        ;;
    "CRI-O")
        sudo kubeadm init --upload-certs \
            --control-plane-endpoint="$1:6443" \
            --apiserver-advertise-address="$1" \
            --cri-socket unix:///var/run/crio/crio.sock
        ;;
    *)
        clear
        echo -e "\nInvalid Option!\n"
        exit 1
        ;;
esac

if [ -f /etc/kubernetes/admin.conf ]; then
    mkdir -p "$HOME/.kube"
    sudo cp -f /etc/kubernetes/admin.conf "$HOME/.kube/config"
    sudo chown "$(id -u)":"$(id -g)" "$HOME/.kube/config"
    export KUBECONFIG="$HOME/.kube/config"
else
    exit 1
fi

### Install Weave as a Network Plugin
VER_LATEST_WEAVE=$(curl --silent -qI https://github.com/weaveworks/weave/releases/latest | awk -F '/' '/^location/ {print substr($NF, 1, length($NF)-1)}');
kubectl apply -f https://github.com/weaveworks/weave/releases/download/$VER_LATEST_WEAVE/weave-daemonset-k8s.yaml;

### Append mode: "ipvs"
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/mode: \"\"/mode: \"ipvs\"/" | \
kubectl apply -f - -n kube-system;

### Append strictARP: true
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system;

### Add MetalLB (Load Balancing in a VMs Cluster)
helm repo add metallb https://metallb.github.io/metallb || true;
kubectl create namespace metallb-system || true;
helm upgrade --install metallb metallb/metallb --set crds.validationFailurePolicy=Ignore -n metallb-system;

### Install NGINX Ingress Controller
VER_NGINX_INGRESS_CONTROLLER=$(curl --silent -qI https://github.com/kubernetes/ingress-nginx/releases/latest/download/ | awk -F '/' '/^location/ {print substr($NF, 1, length($NF)-1)}');
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/$VER_NGINX_INGRESS_CONTROLLER/deploy/static/provider/cloud/deploy.yaml;

### Install Kgateway Gateway API
VER_KGATEWAY=$(curl --silent -qI https://github.com/kubernetes-sigs/gateway-api/releases/latest | awk -F '/' '/^location/ {print substr($NF, 1, length($NF)-1)}');
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$VER_KGATEWAY/standard-install.yaml;
VER_KGATEWAY_HELM=$(curl --silent -qI https://github.com/kgateway-dev/kgateway/releases/latest | awk -F '/' '/^location/ {print substr($NF, 1, length($NF)-1)}');
helm upgrade --install --create-namespace --namespace kgateway-system --version "$VER_KGATEWAY_HELM" kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds;
helm upgrade --install --namespace kgateway-system --version "$VER_KGATEWAY_HELM" kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway;