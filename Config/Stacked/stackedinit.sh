#!/bin/bash

# Initialization based on CRI

cri_used=""
case $2 in
    "Docker")
        cri_used="unix:///var/run/cri-dockerd.sock"
        ;;
    "Containerd")
        cri_used="unix:///run/containerd/containerd.sock"
        ;;
    "CRI-O")
        cri_used="unix:///var/run/crio/crio.sock"
        ;;
    *)
        clear
        echo -e "\nInvalid Option!\n"
        ;;
esac

cat <<EOF > /tmp/kubeadm_config.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "$1"
  bindPort: 6443
nodeRegistration:
  criSocket: "$cri_used"
  ignorePreflightErrors:
    - all
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
controlPlaneEndpoint: "$3:6443"
certificatesDir: "/etc/kubernetes/pki"
etcd:
  local:
    extraArgs:
    - name: election-timeout
      value: "5000"
    - name: heartbeat-interval
      value: "250"
    - name: quota-backend-bytes
      value: "4294967296"
EOF
sudo kubeadm init --upload-certs --config /tmp/kubeadm_config.yaml

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