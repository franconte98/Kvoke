#!/bin/bash

### ============================================================
###  FUNCTIONS
### ============================================================

function initDocker {
    VER_CRI_DOCKER=$(curl --silent -qI https://github.com/Mirantis/cri-dockerd/releases/latest | \
        awk -F '/' '/^location/ {print substr($NF, 1, length($NF)-1)}')

    TMP_TGZ="cri-dockerd-${VER_CRI_DOCKER#v}.amd64.tgz"
    rm -f $TMP_TGZ
    wget -q https://github.com/Mirantis/cri-dockerd/releases/download/$VER_CRI_DOCKER/$TMP_TGZ
    tar -xvf $TMP_TGZ --overwrite
    rm -f $TMP_TGZ

    sudo apt-get install -y --reinstall docker.io docker-buildx

    sudo systemctl enable --now docker

    cd cri-dockerd || exit
    mkdir -p /usr/local/bin
    install -o root -g root -m 0755 ./cri-dockerd /usr/local/bin/cri-dockerd

    # Overwrite systemd units every run
    sudo tee /etc/systemd/system/cri-docker.service > /dev/null << EOF
[Unit]
Description=CRI Interface for Docker Application Container Engine
After=network-online.target firewalld.service docker.service
Wants=network-online.target
Requires=cri-docker.socket
[Service]
Type=notify
ExecStart=/usr/local/bin/cri-dockerd --container-runtime-endpoint fd:// --network-plugin=cni
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=2
Delegate=yes
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

    sudo tee /etc/systemd/system/cri-docker.socket > /dev/null << EOF
[Unit]
Description=CRI Docker Socket for the API
PartOf=cri-docker.service
[Socket]
ListenStream=%t/cri-dockerd.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker
[Install]
WantedBy=sockets.target
EOF

    sudo systemctl daemon-reexec
    sudo systemctl enable --now cri-docker.service cri-docker.socket
}

function initContainerd {
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y --reinstall containerd.io

    sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
    sudo sed -i 's/^SystemdCgroup = .*/SystemdCgroup = true/' /etc/containerd/config.toml

    sudo systemctl daemon-reexec
    sudo systemctl restart containerd
    sudo systemctl enable containerd --now

    VER_CRICTL=$(curl --silent -qI https://github.com/kubernetes-sigs/cri-tools/releases/latest | \
        awk -F '/' '/^location/ {print substr($NF, 1, length($NF)-1)}')

    TMP_CRI="crictl-$VER_CRICTL-linux-amd64.tar.gz"
    rm -f $TMP_CRI
    wget -q -O $TMP_CRI https://github.com/kubernetes-sigs/cri-tools/releases/download/$VER_CRICTL/$TMP_CRI
    sudo tar zxvf $TMP_CRI -C /usr/local/bin --overwrite
    rm -f $TMP_CRI
}

function initCrio {
    sudo apt-get update -y
    sudo apt-get install -y software-properties-common

    sudo rm -f /etc/apt/keyrings/cri-o-apt-keyring.gpg
    sudo curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | \
        sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg --yes
    echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | \
        sudo tee /etc/apt/sources.list.d/cri-o.list

    sudo apt-get update -y
    sudo apt-get install -y --reinstall cri-o

    sudo systemctl daemon-reexec
    sudo systemctl enable crio --now
    sudo systemctl restart crio

    VER_CRICTL=$(curl --silent -qI https://github.com/kubernetes-sigs/cri-tools/releases/latest | \
        awk -F '/' '/^location/ {print substr($NF, 1, length($NF)-1)}')

    TMP_CRI="crictl-$VER_CRICTL-linux-amd64.tar.gz"
    rm -f $TMP_CRI
    wget -q -O $TMP_CRI https://github.com/kubernetes-sigs/cri-tools/releases/download/$VER_CRICTL/$TMP_CRI
    sudo tar zxvf $TMP_CRI -C /usr/local/bin --overwrite
    rm -f $TMP_CRI
}

### ============================================================
###  COMMON SETUP
### ============================================================

# Disable Swap
sudo swapoff -a
sudo sed -i '/[/]swap.img/ s/^/#/' /etc/fstab

# Networking
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.conf.default.forwarding = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Common deps
sudo apt-get update -y
sudo apt-get install -y --reinstall net-tools apt-transport-https ca-certificates curl gpg

# Kubernetes version
Version_K8S_Latest="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
Version_K8S_Stable=$(echo $Version_K8S_Latest | cut -d '.' -f 1)"."$(echo $Version_K8S_Latest | cut -d '.' -f 2)

sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/$Version_K8S_Stable/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$Version_K8S_Stable/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y --reinstall kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Helm
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | \
    sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | \
    sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update -y
sudo apt-get install -y --reinstall helm

# CNI Plugins
VER_CNI_PLUGINS=$(curl --silent -qI https://github.com/containernetworking/plugins/releases/latest | \
    awk -F '/' '/^location/ {print substr($NF, 1, length($NF)-1)}')

TMP_CNI="cni-plugins-linux-amd64-$VER_CNI_PLUGINS.tgz"
rm -f $TMP_CNI
wget -q -O $TMP_CNI https://github.com/containernetworking/plugins/releases/download/$VER_CNI_PLUGINS/$TMP_CNI
sudo tar Cxzvf /opt/cni/bin $TMP_CNI --overwrite
rm -f $TMP_CNI

### ============================================================
###  RUNTIME SELECTION
### ============================================================

case $2 in
    "Docker")
        initDocker
        sudo kubeadm config images pull --cri-socket unix:///var/run/cri-dockerd.sock
        ;;
    "Containerd")
        initContainerd
        sudo kubeadm config images pull --cri-socket unix:///run/containerd/containerd.sock
        ;;
    "CRI-O")
        initCrio
        sudo kubeadm config images pull --cri-socket unix:///var/run/crio/crio.sock
        ;;
    *)
        echo "Invalid runtime option. Use Docker | Containerd | CRI-O"
        exit 1
        ;;
esac

### ============================================================
###  KUBELET NODE-IP
### ============================================================

echo 'KUBELET_EXTRA_ARGS="--node-ip='$1'"' | sudo tee /etc/default/kubelet > /dev/null
sudo systemctl daemon-reexec
sudo systemctl restart kubelet
