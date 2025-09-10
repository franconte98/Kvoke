#!/bin/bash

function initDocker {

    VER_CRI_DOCKER=$(curl --silent -qI https://github.com/Mirantis/cri-dockerd/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}'); 
    wget https://github.com/Mirantis/cri-dockerd/releases/download/$VER_CRI_DOCKER/cri-dockerd-${VER_CRI_DOCKER#v}.amd64.tgz;
    tar -xvf cri-dockerd-${VER_CRI_DOCKER#v}.amd64.tgz;
    sudo apt-get install -y docker.io docker-buildx;
    sudo systemctl enable --now docker;
    cd cri-dockerd || exit;
    mkdir -p /usr/local/bin;
    install -o root -g root -m 0755 ./cri-dockerd /usr/local/bin/cri-dockerd;


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
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
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

    sudo systemctl daemon-reload;
    sudo systemctl enable --now cri-docker.socket;
    sudo systemctl enable --now cri-docker.service;
}

function initContainerd {

    sudo install -m 0755 -d /etc/apt/keyrings;
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc;
    sudo chmod a+r /etc/apt/keyrings/docker.asc;

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null;
    sudo apt-get update -y && sudo apt-get install -y containerd.io;

    ### Generate the config file and change the desired attributes
    sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

    ### Reload / Enable / Restart CRI
    systemctl daemon-reload;
    sudo systemctl restart containerd;
    sudo systemctl enable containerd --now;

    ### Install crictl
    VER_CRICTL=$(curl --silent -qI https://github.com/kubernetes-sigs/cri-tools/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
    wget -O crictl-$VER_CRICTL-linux-amd64.tar.gz https://github.com/kubernetes-sigs/cri-tools/releases/download/$VER_CRICTL/crictl-$VER_CRICTL-linux-amd64.tar.gz
    sudo tar zxvf crictl-$VER_CRICTL-linux-amd64.tar.gz -C /usr/local/bin --overwrite
    rm -f crictl-$VER_CRICTL-linux-amd64.tar.gz
}

function initCrio {

    ### Pre-Installation Cri-O
    sudo apt-get install -y software-properties-common;
    curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/cri-o.list;

    ### Install, Enable and Start Cri-O
    sudo apt-get install -y cri-o;
    sudo systemctl daemon-reload;
    sudo systemctl enable crio --now;

    ### Install crictl
    VER_CRICTL=$(curl --silent -qI https://github.com/kubernetes-sigs/cri-tools/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
    wget -O crictl-$VER_CRICTL-linux-amd64.tar.gz https://github.com/kubernetes-sigs/cri-tools/releases/download/$VER_CRICTL/crictl-$VER_CRICTL-linux-amd64.tar.gz
    sudo tar zxvf crictl-$VER_CRICTL-linux-amd64.tar.gz -C /usr/local/bin --overwrite
    rm -f crictl-$VER_CRICTL-linux-amd64.tar.gz
}

### Disable Swap in linux
sudo swapoff -a;
sudo sed -i '/[/]swap.img/ s/^/#/' /etc/fstab;

### Setup IPV4
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system;

### Install common dependencies
sudo apt-get update -y;
sudo apt install net-tools apt-transport-https ca-certificates curl gpg -y;
### Retreive the latest version of Kubernetes and store it in $VER_K8S_Latest
Version_K8S_Latest="$(curl -sSL https://dl.k8s.io/release/stable.txt)";
Version_K8S_Stable=$(echo $Version_K8S_Latest | cut -d '.' -f 1)"."$(echo $Version_K8S_Latest | cut -d '.' -f 2);

### Install Kubernetes components
curl -fsSL https://pkgs.k8s.io/core:/stable:/$Version_K8S_Stable/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg;
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/'$Version_K8S_Stable'/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list;
sudo apt-get update -y;
sudo apt-get install -y kubelet kubeadm kubectl;
sudo apt-mark hold kubelet kubeadm kubectl;

### Install Helm
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null;
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list;
sudo apt-get update -y;
sudo apt-get install helm -y;

### CNI Plugins
VER_CNI_PLUGINS=$(curl --silent -qI https://github.com/containernetworking/plugins/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
wget -O cni-plugins-linux-amd64-$VER_CNI_PLUGINS.tgz https://github.com/containernetworking/plugins/releases/download/$VER_CNI_PLUGINS/cni-plugins-linux-amd64-$VER_CNI_PLUGINS.tgz
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-$VER_CNI_PLUGINS.tgz --overwrite

### Install all the necessary components of K8S Architecture Based on the CRI
case $2 in
    "Docker")
        initDocker;
        sudo kubeadm config images pull --cri-socket unix:///var/run/cri-dockerd.sock;
        ;;
    "Containerd")
        initContainerd;
        sudo kubeadm config images pull --cri-socket unix:///run/containerd/containerd.sock;
        ;;
    "CRI-O")
        initCrio;
        sudo kubeadm config images pull --cri-socket unix:///var/run/crio/crio.sock;
        ;;
    *)
        clear
        echo -e "\nInvalid Option!\n"
        ;;
esac

### Set Up Internal-IP of the Node
echo 'KUBELET_EXTRA_ARGS="--node-ip='$1'"' | sudo tee /etc/default/kubelet > /dev/null;
systemctl restart kubelet;