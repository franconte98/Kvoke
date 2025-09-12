#!/bin/bash

############################################################################################################################
##                                                  Variables                                                             ##
############################################################################################################################

### --- Whiptail Color ---
export NEWT_COLORS='
root=,gray
'

# --- ANSI Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Global Variables ---

### Functional Variables
CHOICE=""
CHOICE_JOIN=""
CONF_CHOICE=""
declare -A worker_ips
declare -A master_ips
count_workers=0
count_masters=0
ip_master=""
username=""
passwd=""
choose_cidr=false
ip_min=""
ip_max=""
lb_cidr=""
show_range=""
lb_ip=""
network_interface=""
ip_to_join=""

### Tools
cri=""
OUTPUT_FILE="hosts"
OUTPUT_LOGS="/var/log/kvoke/kvoke.logs"


############################################################################################################################
##                                                  Texts                                                                 ##
############################################################################################################################


# shellcheck disable=SC2046
WELCOME_MESSAGE=$(cat <<'EOF'
This script will guide you through the initial setup and preliminary configuration of a Kubernetes cluster.
This IaC script suite automates Kubernetes cluster installation and configuration. 
It includes three official node-joining configurations, adaptable to your available infrastructure.

VMs REQUIREMENTS:
- Each VM requires a unique IP address.
- All VMs must reside on the same network (and must be reachable for each other).
- At least 2vCPU, 4GB of RAM and 25GB of storage for each VM.
- All the VMs got to have the same sudoer user (With the same username and password).
EOF
)

WELCOME_JOIN_1=$(cat <<'EOF'
This script prepares and joins a worker node to a Kvoke cluster. 
It automates the entire process, including the installation of necessary tools, 
the configuration of the container runtime, and the final joining of the node to the cluster.

VM REQUIREMENTS:
- The VM requires a unique IP address.
- All VMs must reside on the same network (and must be reachable for each other), including the node to Join.
- The node needs at least 2vCPU, 4GB of RAM and 25GB of storage.
- All the VMs got to have the same sudoer user (With the same username and password), including the node to Join.
EOF
)

WELCOME_1=$(cat <<'EOF'
This cluster configuration requires less infrastructure then any other type of configuration, but it's less focused on high availability (NON-HA). 
It is composed of only ONE Master node, and up to 10 Working nodes.
It's an optimal choice for simple clusters that can be used for testing environments or simple projects.

MINIMUM REQUIREMENTS:
- 1 Master Node
- 1, up to 10 Worker Nodes

VMs REQUIREMENTS:
- Each VM requires a unique IP address.
- All VMs must reside on the same network (and must be reachable for each other).
- At least 2vCPU, 4GB of RAM and 25GB of storage for each VM.
- All the VMs got to have the same sudoer user (With the same username and password).
EOF
)

WELCOME_2=$(cat <<'EOF'
This configuration demands a more detailed infrastructure but provides optimal High Availability (HA). 
It embeds the etcd components directly within each master node, leveraging a quorum algorithm to ensure the cluster 
remains fully operational as long as a majority of these nodes are active.

MINIMUM REQUIREMENTS:
- 3 Master Nodes, up to 7
- Up to 10 Worker Nodes
- 1 free IP as a VIP

VMs REQUIREMENTS:
- Each VM requires a unique IP address.
- All VMs must reside on the same network (and must be reachable for each other).
- At least 2vCPU, 4GB of RAM and 25GB of storage for each VM.
- All the VMs got to have the same sudoer user (With the same username and password).
EOF
)

USERNAME_MSG=$(cat <<'EOF'
Type the Username for the SSH connection with the VMs.

Remember that the User has to be a sudoer, and have the same credentials for each VM.

EOF
)

PASSWORD_MSG=$(cat <<'EOF'
Type the Password for the SSH connection with the VMs.

Remember that the User has to be a sudoer, and have the same credentials for each VM.

EOF
)

function confirm_page {
    case $CONF_CHOICE in
        1)
            CONFIRM=$(cat <<EOF
Adopted configuration: Simple Configuration (NON-HA)\n
Number of Working Nodes: $count_workers\n
IP Master: $ip_master
$dialog_text
IP Address Pool for Load Balancers: $show_range\n
Container Runtime used: $cri\n
Credentials SSH sudoer\n
Username: $username
Password: $passwd
EOF
)
            ;;
        2)
            CONFIRM=$(cat <<EOF
Adopted configuration: Stacked Configuration (HA)\n
Number of Master Nodes: $count_masters\n
Number of Working Nodes: $count_workers\n
$text_masters
$text_workers
VIP KeepAliveD: $lb_ip\n
IP Address Pool for Load Balancers: $show_range\n
Container Runtime used: $cri\n
Credentials SSH sudoer\n
Username: $username
Password: $passwd
EOF
)
            ;;
        *)
            clear
            echo -e "\nInvalid Option!\n"
            ;;
    esac
}

function confirm_page_join {
    case $CHOICE_JOIN in
        1)
            CONFIRM=$(cat <<EOF
Type of Node that is joining: Worker\n
IP / VIP Node: $ip_master\n
Container Runtime used: $this_cri\n
Credentials SSH sudoer\n
Username: $this_username
Password: $this_password
EOF
)
            ;;
        *)
            clear
            echo -e "\nInvalid Option!\n"
            ;;
    esac
}