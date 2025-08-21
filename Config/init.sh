#!/bin/bash

function initDocker {
    ### Install Docker CRI
    VER_CRI_DOCKER=$(curl --silent -qI https://github.com/Mirantis/cri-dockerd/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
    wget -O cri-dockerd-${VER_CRI_DOCKER#v}.amd64.tgz https://github.com/Mirantis/cri-dockerd/releases/download/$VER_CRI_DOCKER/cri-dockerd-${VER_CRI_DOCKER#v}.amd64.tgz;
    tar -xvf cri-dockerd-${VER_CRI_DOCKER#v}.amd64.tgz --overwrite;
    sudo apt install docker.io -y;
    systemctl enable --now docker;
    cd cri-dockerd || exit;
    mkdir -p /usr/local/bin;
    install -o root -g root -m 0755 ./cri-dockerd /usr/local/bin/cri-dockerd;
    sudo apt install docker-buildx -y;

    ### Set up the Docker CRI 1° (Only docker-network-bridge => --network-plugin=)
    sudo tee /etc/systemd/system/cri-docker.service << EOF
    [Unit]
    Description=CRI Interface for Docker Application Container Engine
    After=network-online.target firewalld.service docker.service
    Wants=network-online.target
    Requires=cri-docker.socket
    [Service]
    Type=notify
    ExecStart=/usr/local/bin/cri-dockerd --container-runtime-endpoint fd:// --network-plugin=cni
    ExecReload=/bin/kill -s HUP $MAINPID
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

    ### Set up the Docker CRI 2°
    sudo tee /etc/systemd/system/cri-docker.socket << EOF
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

    ### Reload / Enable / Restart CRI
    systemctl daemon-reload;
    systemctl enable --now cri-docker.socket;
    systemctl enable --now cri-docker;
}

function initContainerd {
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update && sudo apt-get install containerd.io && systemctl enable --now containerd

    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
EOF
    sudo modprobe overlay
    sudo modprobe br_netfilter

    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward = 1
EOF

    sudo sysctl --system
    sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
    modprobe br_netfilter
    sysctl -p /etc/sysctl.conf

    cat <<EOF | sudo tee /etc/containerd/config.toml
    disabled_plugins = []
    imports = []
    oom_score = 0
    plugin_dir = ""
    required_plugins = []
    root = "/var/lib/containerd"
    state = "/run/containerd"
    version = 2

    [cgroup]
    path = ""

    [debug]
    address = ""
    format = ""
    gid = 0
    level = ""
    uid = 0

    [grpc]
    address = "/run/containerd/containerd.sock"
    gid = 0
    max_recv_message_size = 16777216
    max_send_message_size = 16777216
    tcp_address = ""
    tcp_tls_cert = ""
    tcp_tls_key = ""
    uid = 0

    [metrics]
    address = ""
    grpc_histogram = false

    [plugins]

    [plugins."io.containerd.gc.v1.scheduler"]
        deletion_threshold = 0
        mutation_threshold = 100
        pause_threshold = 0.02
        schedule_delay = "0s"
        startup_delay = "100ms"

    [plugins."io.containerd.grpc.v1.cri"]
        disable_apparmor = false
        disable_cgroup = false
        disable_hugetlb_controller = true
        disable_proc_mount = false
        disable_tcp_service = true
        enable_selinux = false
        enable_tls_streaming = false
        ignore_image_defined_volumes = false
        max_concurrent_downloads = 3
        max_container_log_line_size = 16384
        netns_mounts_under_state_dir = false
        restrict_oom_score_adj = false
        sandbox_image = "k8s.gcr.io/pause:3.5"
        selinux_category_range = 1024
        stats_collect_period = 10
        stream_idle_timeout = "4h0m0s"
        stream_server_address = "127.0.0.1"
        stream_server_port = "0"
        systemd_cgroup = false
        tolerate_missing_hugetlb_controller = true
        unset_seccomp_profile = ""

        [plugins."io.containerd.grpc.v1.cri".cni]
        bin_dir = "/opt/cni/bin"
        conf_dir = "/etc/cni/net.d"
        conf_template = ""
        max_conf_num = 1

        [plugins."io.containerd.grpc.v1.cri".containerd]
        default_runtime_name = "runc"
        disable_snapshot_annotations = true
        discard_unpacked_layers = false
        no_pivot = false
        snapshotter = "overlayfs"

        [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime]
            base_runtime_spec = ""
            container_annotations = []
            pod_annotations = []
            privileged_without_host_devices = false
            runtime_engine = ""
            runtime_root = ""
            runtime_type = ""

            [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime.options]

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]

            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
            base_runtime_spec = ""
            container_annotations = []
            pod_annotations = []
            privileged_without_host_devices = false
            runtime_engine = ""
            runtime_root = ""
            runtime_type = "io.containerd.runc.v2"

            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
                BinaryName = ""
                CriuImagePath = ""
                CriuPath = ""
                CriuWorkPath = ""
                IoGid = 0
                IoUid = 0
                NoNewKeyring = false
                NoPivotRoot = false
                Root = ""
                ShimCgroup = ""
                SystemdCgroup = true

        [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime]
            base_runtime_spec = ""
            container_annotations = []
            pod_annotations = []
            privileged_without_host_devices = false
            runtime_engine = ""
            runtime_root = ""
            runtime_type = ""

            [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime.options]

        [plugins."io.containerd.grpc.v1.cri".image_decryption]
        key_model = "node"

        [plugins."io.containerd.grpc.v1.cri".registry]
        config_path = ""

        [plugins."io.containerd.grpc.v1.cri".registry.auths]

        [plugins."io.containerd.grpc.v1.cri".registry.configs]

        [plugins."io.containerd.grpc.v1.cri".registry.headers]

        [plugins."io.containerd.grpc.v1.cri".registry.mirrors]

        [plugins."io.containerd.grpc.v1.cri".x509_key_pair_streaming]
        tls_cert_file = ""
        tls_key_file = ""

    [plugins."io.containerd.internal.v1.opt"]
        path = "/opt/containerd"

    [plugins."io.containerd.internal.v1.restart"]
        interval = "10s"

    [plugins."io.containerd.metadata.v1.bolt"]
        content_sharing_policy = "shared"

    [plugins."io.containerd.monitor.v1.cgroups"]
        no_prometheus = false

    [plugins."io.containerd.runtime.v1.linux"]
        no_shim = false
        runtime = "runc"
        runtime_root = ""
        shim = "containerd-shim"
        shim_debug = false

    [plugins."io.containerd.runtime.v2.task"]
        platforms = ["linux/amd64"]

    [plugins."io.containerd.service.v1.diff-service"]
        default = ["walking"]

    [plugins."io.containerd.snapshotter.v1.aufs"]
        root_path = ""

    [plugins."io.containerd.snapshotter.v1.btrfs"]
        root_path = ""

    [plugins."io.containerd.snapshotter.v1.devmapper"]
        async_remove = false
        base_image_size = ""
        pool_name = ""
        root_path = ""

    [plugins."io.containerd.snapshotter.v1.native"]
        root_path = ""

    [plugins."io.containerd.snapshotter.v1.overlayfs"]
        root_path = ""

    [plugins."io.containerd.snapshotter.v1.zfs"]
        root_path = ""

    [proxy_plugins]

    [stream_processors]

    [stream_processors."io.containerd.ocicrypt.decoder.v1.tar"]
        accepts = ["application/vnd.oci.image.layer.v1.tar+encrypted"]
        args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
        env = ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]
        path = "ctd-decoder"
        returns = "application/vnd.oci.image.layer.v1.tar"

    [stream_processors."io.containerd.ocicrypt.decoder.v1.tar.gzip"]
        accepts = ["application/vnd.oci.image.layer.v1.tar+gzip+encrypted"]
        args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
        env = ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]
        path = "ctd-decoder"
        returns = "application/vnd.oci.image.layer.v1.tar+gzip"

    [timeouts]
    "io.containerd.timeout.shim.cleanup" = "5s"
    "io.containerd.timeout.shim.load" = "5s"
    "io.containerd.timeout.shim.shutdown" = "3s"
    "io.containerd.timeout.task.state" = "2s"

    [ttrpc]
    address = ""
    gid = 0
    uid = 0
EOF

    ### Reload / Enable / Restart CRI
    systemctl daemon-reload;
    sudo systemctl restart containerd;
    sudo systemctl enable containerd --now;
}

function initCrio {

    ### Pre-Installation Cri-O
    sudo apt-get install -y software-properties-common
    curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/cri-o.list
    sudo apt-get update -y

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
swapoff -a;
sed -i '/[/]swap.img/ s/^/#/' /etc/fstab;

### Get the tools for Logging and Networking on Linux
sudo apt install net-tools;
sudo apt-get update -y;

### Retreive the latest version of Kubernetes and store it in $VER_K8S_Latest
Version_K8S_Latest="$(curl -sSL https://dl.k8s.io/release/stable.txt)";
Version_K8S_Stable=$(echo $Version_K8S_Latest | cut -d '.' -f 1)"."$(echo $Version_K8S_Latest | cut -d '.' -f 2);

### Install Kubernetes components
sudo apt-get install -y apt-transport-https ca-certificates curl gpg;
curl -fsSL https://pkgs.k8s.io/core:/stable:/$Version_K8S_Stable/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg;
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/'$Version_K8S_Stable'/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list;
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null;
sudo apt-get update -y;
sudo apt-get install -y kubelet kubeadm kubectl;
sudo apt-mark hold kubelet kubeadm kubectl;

### Install Helm
sudo apt-get install apt-transport-https --yes;
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list;
sudo apt-get update -y;
sudo apt-get install -y helm;

### Container Runtime Initialization (CRI)
case $2 in
    "Containerd")
        initContainerd;
        ;;
    "Docker")
        initDocker;
        ;;
    "CRI-O")
        initCrio;
        ;;
    *)
        clear
        echo -e "\nInvalid Option!\n"
        ;;
esac

### CNI Plugins
VER_CNI_PLUGINS=$(curl --silent -qI https://github.com/containernetworking/plugins/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
wget -O cni-plugins-linux-amd64-$VER_CNI_PLUGINS.tgz https://github.com/containernetworking/plugins/releases/download/$VER_CNI_PLUGINS/cni-plugins-linux-amd64-$VER_CNI_PLUGINS.tgz
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-$VER_CNI_PLUGINS.tgz --overwrite

### Setup IPV4
echo "memory swapoff";
sudo modprobe overlay;
sudo modprobe br_netfilter;
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

### Install and setup Docker Compose (allow to handle containers, images and volumes through YAMLs) [Retreive the latest]
if [[ $2 == "Docker" ]]; then
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker};
    mkdir -p "$DOCKER_CONFIG/cli-plugins";
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o "$DOCKER_CONFIG/cli-plugins/docker-compose";
    chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose";
fi

### Install all the necessary components of K8S Architecture right inside Docker
sysctl --system;
sudo systemctl enable kubelet;
case $2 in
    "Docker")
        sudo kubeadm config images pull --cri-socket unix:///var/run/cri-dockerd.sock;
        ;;
    "Containerd")
        sudo kubeadm config images pull --cri-socket unix:///run/containerd/containerd.sock;
        ;;
    "CRI-O")
        sudo kubeadm config images pull --cri-socket unix:///var/run/crio/crio.sock;
        ;;
    *)
        clear
        echo -e "\nInvalid Option!\n"
        ;;
esac

### Set Up Internal-IP of the Node
echo 'KUBELET_EXTRA_ARGS="--node-ip='$1'"' > /etc/default/kubelet;
systemctl restart kubelet;

### Install Weave Tool for each node in the cluster (Only on Docker-CRI)
if [[ $2 == "Docker" ]]; then
    sudo curl -L git.io/weave -o /usr/local/bin/weave;
    sudo chmod +x /usr/local/bin/weave;
fi