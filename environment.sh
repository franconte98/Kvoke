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

### Tools
cri=""
OUTPUT_FILE="hosts"
OUTPUT_LOGS="/var/log/kinit/kinit.logs"


############################################################################################################################
##                                                  Texts                                                                 ##
############################################################################################################################


# shellcheck disable=SC2046
WELCOME_MESSAGE=$(cat <<'EOF'
This script will guide you through the initial setup and preliminary configuration of a Kubernetes cluster.
This IaC script suite automates Kubernetes cluster installation and configuration. 
It includes three official node-joining configurations, adaptable to your available infrastructure.

VMs REQUIREMENTS::
- Each VM requires a unique IP address.
- All VMs must reside on the same network (and must be reachable for each other).
- At least 2vCPU, 2GB of RAM and 25GB of storage for each VM.
- All the VMs got to have the same sudoer user (With the same username and password).
EOF
)

WELCOME_1=$(cat <<'EOF'
This cluster configuration requires less infrastructure then any other type of configuration, but it's less focused on high availability (NON-HA). 
It is composed of only ONE Master node, and up to 10 Working nodes.
It's an optimal choice for simple clusters that can be used for testing environments or simple projects.

MINIMUM REQUIREMENTS:
- 1 Master Node
- 1, up to 10 Worker Nodes

VMs REQUIREMENTS::
- Each VM requires a unique IP address.
- All VMs must reside on the same network (and must be reachable for each other).
- At least 2vCPU, 2GB of RAM and 25GB of storage for each VM.
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

function confirm_text_1 {
    CONFIRM_SIMPLE=$(cat <<EOF
Adopted configuration: Basic Non-High Availability Setup\n
Number of Working Nodes: $count_workers\n
Master IP $ip_master\n
$dialog_text
IPAddressPool for LB: $show_range\n
Container Runtime: $cri\n\n
Credentials SSH non-ROOT:\n
Username: $username
Password: $passwd
EOF
)
}