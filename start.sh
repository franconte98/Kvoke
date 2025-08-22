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
##                                            Functions                                                                   ##
############################################################################################################################

# --- Function called when aborting the execution ---
function abortExec {
    echo "Aborting the execution of Kinit. Check the logs in $OUTPUT_LOGS"
    exit 1;
}

# --- Function Used to make Logs ---
function log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a $OUTPUT_LOGS
}

# --- Simple Function to Make sure there is a Min-Max on a given Value ---
function validate_range() {
  local value="$1"
  local MIN_VALUE="$2"
  local MAX_VALUE="$3"

  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo -e "INVALID number!\n"
    return 1
  fi

  if (( value > MIN_VALUE && value < MAX_VALUE )); then
    return 0
  else
    echo -e "INVALID number!\n"
    return 1
  fi
}

# --- Main Menu, here everything start! ---
function mainMenu {

    # --- 1. Welcome! ---
    whiptail --title "KINIT - the K8S OnPremise Cluster Initiator!" \
            --msgbox "This script will guide you through the initial setup and preliminary configuration of a Kubernetes cluster. 
                    This IaC script suite automates Kubernetes cluster installation and configuration. 
                    It includes three official node-joining configurations, adaptable to your available infrastructure.\n\n
                    VM Prerequisites:
                    - Each VM requires a unique IP address.
                    - All VMs must reside on the same network (and must be reachable for each other).
                    - At least 2vCPU, 2Gi of TAM and 40Gb of storage for each VM.
                    - All the VMs got to have the same sudoer user (With the same username and password).
            " $(stty size)

    # --- First Choice ---
    CHOICE=$(whiptail --title "Choose an Option" \
        --menu "Select what you wanna do right now." $(stty size) 2 \
        "1" "Create a Kinit Cluster" \
        "2" "Join a Node to a Kinit Cluster" \
        3>&1 1>&2 2>&3)

    # --- Routing w// switch ---
    case $CHOICE in
        1)
            createMenu
            ;;
        2)
            joinMenu
            ;;
        *)
            clear
            echo -e "\nInvalid Option!\n"
            ;;
    esac
}

####################
##  Join Cluster  ## HAS TO BE IMPLEMENTED!!
####################

# --- Join Cluster Menu ---
# mainMenu -> joinMenu
function joinMenu {

    # --- Menu ---

    whiptail --title "Join Node" \
            --msgbox "Once you initialized a k8s cluster, to join a node to the cluster" $(stty size)
    
    this_ip=$(whiptail --title "Enter the IP of the Node" \
            --inputbox "Type the IP of the node you wanna Join to your Cluster." $(stty size) \
            "192.168.100.10" \
            3>&1 1>&2 2>&3)
    
    this_cri=$(whiptail --title "Container Runtime Interface" \
        --menu "Select which CNI you wanna use for that node" $(stty size) 3 \
        "Docker" "The most widely adopted and well-documented container runtime, it allows for simple container management." \
        "Containerd" "Highly adopted, minimal container runtime." \
        "CRI-O" "A lightweight, Kubernetes-specific container runtime." \
        3>&1 1>&2 2>&3)
    
    this_username=$(whiptail --title "Username for SSH" \
        --inputbox "Type the username for the SSH connection with the VM:" $(stty size) \
        "username" \
        3>&1 1>&2 2>&3)

    this_password=$(whiptail --title "Password for SSH" \
        --passwordbox "Type the password for the SSH connection with the VM:" $(stty size) "" \
        3>&1 1>&2 2>&3)

    confirmMenuJoin
}

# --- Confirmation Menu Function Join ---
# joinMenu -> confirmMenuJoin
function confirmMenuJoin {

    ### RECAP
    whiptail --title "Configuration Overview" \
            --msgbox "IP Node: $ip_master\n
    Role: Worker\n
    Container Runtime: $this_cri\n
    Credentials SSH non-ROOT:
    Username: $this_username
    Password: $this_password
    " $(stty size)

    # --- 6. Confirm Choice ---
    if (whiptail --title "Final Confirmation" \
                --yesno "Do you confirm these settings to proceed with the installation?" $(stty size)); then
        initJoin
        clear
    else
        clear
        mainMenu
    fi

}

# --- Initialization of the Join Cluster ---
# confirmMenuJoin -> initJoin
function initJoin {
    
    ### Install Tool for Automated SSH
    sudo apt install sshpass -y;

    ### init.sh
    echo -e "\n Node Initialization with IP $this_ip\n"
    partial_join_command="$(kubeadm token create --print-join-command)";
    case $this_cri in
        "Docker")
            JOIN_COMMAND="$partial_join_command --cri-socket unix:///var/run/cri-dockerd.sock";
            ;;
        "Containerd")
            JOIN_COMMAND="$partial_join_command --cri-socket unix:///run/containerd/containerd.sock";
            ;;
        "CRI-O")
            JOIN_COMMAND="$partial_join_command --cri-socket unix:///var/run/crio/crio.sock";
            ;;
        *)
            clear
            echo -e "\nInvalid Option!\n"
            ;;
    esac
    sshpass -p $this_password scp -o StrictHostKeyChecking=no init.sh $this_username@$this_ip:init.sh
    sshpass -p $this_password ssh -o StrictHostKeyChecking=no $this_username@$this_ip "echo $this_password | sudo -S ./init.sh \"$this_ip\" \"$this_cri\""
    sshpass -p $this_password ssh -o StrictHostKeyChecking=no $this_username@$this_ip "echo $this_password | sudo -S bash -c \"$JOIN_COMMAND\""

    clear
    echo -e "\n${NC}${GREEN}#######################################################################################${NC}\n"
    echo -e "\n Join of the node should be successful! Check your cluster using the 'k9s' command.\n"
    echo -e "\n${NC}${GREEN}#######################################################################################${NC}\n"
}

######################
##  Create Cluster  ##
######################

# --- Create Cluster Menu ---
# mainMenu -> createMenu
function createMenu {

    # --- First Option for Creation ---
    CONF_CHOICE=$(whiptail --title "Configuration Options" \
        --menu "Select which cluster configuration you wanna instantiate." $(stty size) 4 \
        "1" "Basic Non-High Availabile Configuration (less-infrastructure)" \
        "2" "Stacked Configuration (HA)" \
        3>&1 1>&2 2>&3)

    # --- Routing w// switch ---
    case $CONF_CHOICE in
        1)
            menuSimple
            ;;
        2)
            menuStacked
            ;;
        *)
            clear
            echo -e "\nInvalid Option!\n"
            ;;
    esac
    
}

#############################
##  NON-HA Create Cluster  ##
#############################

# --- Create a NON-HA Cluster Menu ---

# --- Create Inventory Function ---
function inventorySimple {
    
    rm -rf $OUTPUT_FILE;
    # Master
    echo "[masters]" >> "$OUTPUT_FILE"
    echo "$ip_master" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # Workers
    echo "[workers]" >> "$OUTPUT_FILE"
    for (( c=1; c<=$count_workers; c++ ))
    do
        echo "${worker_ips[$c]}" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"

    # All IPs
    echo "[all_vms:children]" >> "$OUTPUT_FILE"
    echo "masters" >> "$OUTPUT_FILE"
    echo "workers" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # Credentials and Attributes
    echo "[all_vms:vars]" >> "$OUTPUT_FILE"
    echo "ansible_user=$username" >> "$OUTPUT_FILE"
    echo "ansible_ssh_pass=$passwd" >> "$OUTPUT_FILE"
    echo "ansible_become_pass=$passwd" >> "$OUTPUT_FILE"
    echo "count_workers=$count_workers" >> "$OUTPUT_FILE"
    for (( c=1; c<=$count_workers; c++ ))
    do
        echo "worker$c=${worker_ips[$c]}" >> "$OUTPUT_FILE"
    done
    echo "master_ip=$ip_master" >> "$OUTPUT_FILE"
    echo "cri=$cri" >> "$OUTPUT_FILE"
    echo "username=$username" >> "$OUTPUT_FILE"
    echo "passwd=$passwd" >> "$OUTPUT_FILE"

}

# createMenu -> menuSimple
function menuSimple {

    whiptail --title "Basic Non-High Availability Setup" \
        --msgbox "This cluster configuration requires less infrastructure, but it's less focused on high availability (NON-HA). [~ 10 minutes to create it]
    \nMINIMUM REQUIREMENTS:
    - 1 Master Node
    - 1, up to 10 Worker Nodes
    \nNETWORK PREREQUISITES:- Each VM requires a unique IP address.
    - All VMs must reside on the same network (and must be reachable for each other).
    - At least 2vCPU, 2Gi of RAM and 40Gb of Storage for each VM.
    - All the VMs got to have the same sudoer user (With the same username and password).
    " $(stty size)

    ### Number of Working Nodes
    count_workers=$(whiptail --title "Number of Working Nodes" \
        --inputbox "Select the number of Working Node (from 1 up to 10)." $(stty size) \
        "2" \
        3>&1 1>&2 2>&3)
    if ! validate_range "$count_workers" "0" "11"; then
        clear
        echo -e "\nInvalid Option!\n"
        exit 1
    fi

    ### Master Node's IP
    ip_master=$(whiptail --title "Master Node IP" \
        --inputbox "Type the IP of the Master Node (which should be this node)." $(stty size) \
        "192.168.0.100" \
        3>&1 1>&2 2>&3)

    ### Worker Nodes's IP
    for (( c=1; c<=$count_workers; c++ ))
    do
        worker_ips[$c]=$(whiptail --title "Worker Node n°$c IP" \
            --inputbox "Type the IP of the Working Node n°$c." $(stty size) \
            "$ip_master" \
            3>&1 1>&2 2>&3)
    done

    ### IPAddressPool for MetalLB
    if (whiptail --title "IP Address Pool LoadBalancers" --yes-button "Min-Max" --no-button "CIDR" \
            --yesno "Specify the desired IP range for Load Balancers: either Min-Max or a full CIDR block." $(stty size)); then
        choose_cidr=false
        ip_min=$(whiptail --title "Enter the Load Balancer's minimum IP" \
            --inputbox "Type the min IP." $(stty size) \
            "$ip_master" \
            3>&1 1>&2 2>&3)
        ip_max=$(whiptail --title "Enter the Load Balancer's maximum IP" \
            --inputbox "Type the max IP." $(stty size) \
            "$ip_min" \
            3>&1 1>&2 2>&3)
    else
        choose_cidr=true
        lb_cidr=$(whiptail --title "Enter the CIDR for the Load Balancers" \
            --inputbox "Type the CIDR for the Load Balancers." $(stty size) \
            "$ip_master/25" \
            3>&1 1>&2 2>&3)
    fi

    ### SSH Connection Username
    username=$(whiptail --title "Username for SSH" \
        --inputbox "Type the username for the SSH connection with the VMs (non-root user)." $(stty size) \
        "username" \
        3>&1 1>&2 2>&3)

    ### SSH Connection Passwords
    passwd=$(whiptail --title "Password for SSH" \
        --passwordbox "Type the password for the SSH connection with the VMs (non-root user)." $(stty size) "" \
        3>&1 1>&2 2>&3)

    ## CRI Selection
    cri=$(whiptail --title "Container Runtime Interface" \
        --menu "Select which CNI you wanna use:" $(stty size) 3 \
        "Docker" "The most widely adopted and well-documented container runtime, it allows for simple container management." \
        "Containerd" "Highly adopted, minimal container runtime." \
        "CRI-O" "A lightweight, Kubernetes-specific container runtime." \
        3>&1 1>&2 2>&3)

    confirmMenuSimple
}

# --- Confirmation Menu Function Non-HA ---
function confirmMenuSimple {

    dialog_text=""
    for (( c=1; c<=$count_workers; c++ ))
    do
        dialog_text+="\nIP Worker n°$c: ${worker_ips[$c]}\n"
    done

    show_range=""
    if [[ "$choose_cidr" == "true" ]]; then
        show_range="$lb_cidr"
    else
        show_range="$ip_min-$ip_max"
    fi

    ### RECAP
    whiptail --title "Configuration Overview" \
            --msgbox "Adopted configuration: Basic Non-High Availability Setup\n
            Number of Working Nodes: $count_workers\n
            Master IP $ip_master\n
            $dialog_text
            IPAddressPool for LB: $show_range\n
            Container Runtime: $cri\n
            Credentials SSH non-ROOT:\n
            Username: $username
            Password: $passwd
            " $(stty size)

    if (whiptail --title "Final Confirmation" \
                --yesno "Do you confirm these settings to proceed with the installation?" $(stty size)); then
        initSimple
    else
        clear
        mainMenu
    fi
}

# --- Initialization of a Simple NON-HA Cluster [~ 10 minutes] ---
function initSimple {

    ### --- Initialization ---

    clear
    log "Creating K8S Cluster with SIMPLE Configuration"

    ### Install Tools
    log "Installing the Tools necessary for initialization"
    sudo apt update;
    sudo apt install sshpass -y;
    sudo apt install software-properties-common -y;
    sudo add-apt-repository --yes --update ppa:ansible/ansible;
    sudo apt install ansible -y;

    ### Enabling Scripts (Bash)
    chmod +x Config/init.sh Config/Simple/*

    ### Ansible Inventory creation
    inventorySimple

    ### Ping Test
    log "Testing the Connectivity to all the Nodes"
    ansible all_vms -m ping;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} Some VMs are not reachable by Ansible! ${NC}${RED}ABORT.${NC}"
        log "ERROR: Some VMs are not reachable by Ansible!"
        abortExec
    fi

    ### Playbook w// init.sh
    log "Initiating all the Nodes"
    ansible-playbook ./Config/Simple/playbook_init.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} There were some problems and the Initiation did not succeed. ${NC}${RED}ABORT.${NC}"
        log "ERROR: Some VMs are not reachable by Ansible!"
        abortExec
    fi

    ### --- Creation ---

    ### Creating the Cluster
    log "Creating the Cluster"
    ./Config/Simple/masterinit.sh $ip_master $cri
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} Something went wrong initiating the cluster with Kubeadm! ${NC}${RED}ABORT.${NC}"
        log "ERROR: Something went wrong initiating the cluster with Kubeadm!"
        abortExec
    fi

    ### --- Join + Setup ---

    ### Join Nodes
    partial_join_command="$(kubeadm token create --print-join-command)";
    case $cri in
        "Docker")
            JOIN_COMMAND="$partial_join_command --cri-socket unix:///var/run/cri-dockerd.sock";
            ;;
        "Containerd")
            JOIN_COMMAND="$partial_join_command --cri-socket unix:///run/containerd/containerd.sock";
            ;;
        "CRI-O")
            JOIN_COMMAND="$partial_join_command --cri-socket unix:///var/run/crio/crio.sock";
            ;;
        *)
            clear
            echo -e "\nInvalid Option!\n"
            ;;
    esac

    ### Playbook for Joining
    log "Joining all the Nodes"
    ansible-playbook ./Config/Simple/playbook_join.yaml -e "JOIN_COMMAND='$JOIN_COMMAND'";
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} There were some problems and the Worker Nodes did not join. ${NC}${RED}ABORT.${NC}"
        log "ERROR: Some VMs are not reachable by Ansible!"
        abortExec
    fi

    ### IPAddressPool for MetalLB
    cat <<-EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: first-pool
    namespace: metallb-system
spec:
    addresses:
    - $show_range
    autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: l2
    namespace: metallb-system
spec:
    ipAddressPools:
    - first-pool
---
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
    name: example
    namespace: metallb-system
spec:
    ipAddressPools:
    - first-pool
EOF

    ### End Of Process
    log "Installation and Configuration are done!"
    echo -e "\n${NC}${GREEN}#######################################################################################${NC}\n"
    echo -e "\n Installation and Configuration are done! Check your cluster using the 'k9s' command.\n"
    echo -e "\n${NC}${GREEN}#######################################################################################${NC}\n"
}

##############################
##  Stacked Create Cluster  ##
##############################

# --- Create Inventory Function ---
function inventoryStacked {

    rm -rf $OUTPUT_FILE;
    # Masters
    echo "[masters]" >> "$OUTPUT_FILE"
    for (( c=1; c<=$count_masters; c++ ))
    do
        echo "${master_ips[$c]}" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"

    # Workers
    echo "[workers]" >> "$OUTPUT_FILE"
    for (( c=1; c<=$count_workers; c++ ))
    do
        echo "${worker_ips[$c]}" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"

    # All IPs
    echo "[all_vms:children]" >> "$OUTPUT_FILE"
    echo "masters" >> "$OUTPUT_FILE"
    echo "workers" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # Credentials and Attributes
    echo "[all_vms:vars]" >> "$OUTPUT_FILE"
    echo "ansible_user=$username" >> "$OUTPUT_FILE"
    echo "ansible_ssh_pass=$passwd" >> "$OUTPUT_FILE"
    echo "ansible_become_pass=$passwd" >> "$OUTPUT_FILE"
    echo "count_workers=$count_workers" >> "$OUTPUT_FILE"
    for (( c=1; c<=$count_workers; c++ ))
    do
        echo "worker$c=${worker_ips[$c]}" >> "$OUTPUT_FILE"
    done
    echo "count_masters=$count_masters" >> "$OUTPUT_FILE"
    for (( c=1; c<=$count_masters; c++ ))
    do
        echo "master$c=${master_ips[$c]}" >> "$OUTPUT_FILE"
    done
    echo "cri=$cri" >> "$OUTPUT_FILE"
    echo "username=$username" >> "$OUTPUT_FILE"
    echo "passwd=$passwd" >> "$OUTPUT_FILE"
    echo "vip_ip=$lb_ip" >> "$OUTPUT_FILE"

}

# --- Upload Certificates ---
function loadCerts {
    LOAD_CERTS_COMMANDS="
    mkdir -p /etc/kubernetes/pki
    mkdir -p /etc/kubernetes/pki/etcd
    mv "/home/$username/ca.crt" "/etc/kubernetes/pki/ca.crt" && chmod 644 "/etc/kubernetes/pki/ca.crt" && chown root:root "/etc/kubernetes/pki/ca.crt"
    mv "/home/$username/ca.key" "/etc/kubernetes/pki/ca.key" && chmod 600 "/etc/kubernetes/pki/ca.key" && chown root:root "/etc/kubernetes/pki/ca.key"
    mv "/home/$username/etcd-ca.crt" "/etc/kubernetes/pki/etcd/ca.crt" && chmod 644 "/etc/kubernetes/pki/etcd/ca.crt" && chown root:root "/etc/kubernetes/pki/etcd/ca.crt"
    mv "/home/$username/etcd-ca.key" "/etc/kubernetes/pki/etcd/ca.key" && chmod 600 "/etc/kubernetes/pki/etcd/ca.key" && chown root:root "/etc/kubernetes/pki/etcd/ca.key"
    mv "/home/$username/front-proxy-ca.crt" "/etc/kubernetes/pki/front-proxy-ca.crt" && chmod 644 "/etc/kubernetes/pki/front-proxy-ca.crt" && chown root:root "/etc/kubernetes/pki/front-proxy-ca.crt"
    mv "/home/$username/front-proxy-ca.key" "/etc/kubernetes/pki/front-proxy-ca.key" && chmod 600 "/etc/kubernetes/pki/front-proxy-ca.key" && chown root:root "/etc/kubernetes/pki/front-proxy-ca.key"
    mv "/home/$username/sa.pub" "/etc/kubernetes/pki/sa.pub" && chmod 644 "/etc/kubernetes/pki/sa.pub" && chown root:root "/etc/kubernetes/pki/sa.pub"
    mv "/home/$username/sa.key" "/etc/kubernetes/pki/sa.key" && chmod 600 "/etc/kubernetes/pki/sa.key" && chown root:root "/etc/kubernetes/pki/sa.key"
    "

    # --- Certificates Upload ---
    for (( c=2; c<=$count_masters; c++ ))
    do
        sshpass -p $passwd scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/ca.crt $username@${master_ips[$c]}: || { echo "ERROR: Failed to scp ca.crt to ${master_ips[$c]}"; }
        sshpass -p $passwd scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/ca.key $username@${master_ips[$c]}: || { echo "ERROR: Failed to scp ca.key to ${master_ips[$c]}"; }
        sshpass -p $passwd scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/etcd/ca.crt $username@${master_ips[$c]}:etcd-ca.crt || { echo "ERROR: Failed to scp /etcd/ca.crt to ${master_ips[$c]}"; }
        sshpass -p $passwd scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/etcd/ca.key $username@${master_ips[$c]}:etcd-ca.key || { echo "ERROR: Failed to scp /etcd/ca.key to ${master_ips[$c]}"; }
        sshpass -p $passwd scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/front-proxy-ca.crt $username@${master_ips[$c]}: || { echo "ERROR: Failed to scp front-proxy-ca.crt to ${master_ips[$c]}"; }
        sshpass -p $passwd scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/front-proxy-ca.key $username@${master_ips[$c]}: || { echo "ERROR: Failed to scp front-proxy-ca.key to ${master_ips[$c]}"; }
        sshpass -p $passwd scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/sa.pub $username@${master_ips[$c]}: || { echo "ERROR: Failed to scp sa.pub to ${master_ips[$c]}"; }
        sshpass -p $passwd scp -o StrictHostKeyChecking=no /etc/kubernetes/pki/sa.key $username@${master_ips[$c]}: || { echo "ERROR: Failed to scp sa.key to ${master_ips[$c]}"; }
        sshpass -p $passwd ssh -o StrictHostKeyChecking=no $username@${master_ips[$c]} "echo $passwd | sudo -S bash -c \"$LOAD_CERTS_COMMANDS\"" || { echo "ERROR: Failed to execute the LOAD CERTS COMMAND to ${master_ips[$c]}"; }
    done
}

# --- Menu Stacked Configuration ---
function menuStacked {

    # --- 1 MessageBox per Avvisare ---
    whiptail --title "Stacked Configuration Cluster Setup" \
        --msgbox "This configuration demands a more detailed infrastructure but provides optimal High Availability (HA). 
        It embeds the etcd components directly within each master node, leveraging a quorum algorithm to ensure the cluster 
        remains fully operational as long as a majority of these nodes are active.
    \nMINIMUM REQUIREMENTS:
    - 3 Master Nodes, up to 7
    - Up to 10 Worker Nodes
    - 1 free IP as a VIP
    \nNETWORK PREREQUISITES:
    - All VMs must reside on the same network (and must be reachable for each other).
    - At least 2vCPU, 2Gi of RAM and 40Gb of Storage for each VM.
    - All the VMs got to have the same sudoer user (With the same username and password).
    " $(stty size)

    # --- 2 Input dei valori per IPs, N° Working Nodes e Credenziali ---

    ### Numero dei Master Nodes
    count_masters=$(whiptail --title "Number of Master Nodes" \
        --inputbox "Select the number of Master Nodes (from 3 up to 7). An Odd number is strongly advised." $(stty size) \
        "3" \
        3>&1 1>&2 2>&3)
    if ! validate_range "$count_masters" "2" "8"; then
        clear
        echo -e "\nInvalid Option!\n"
        exit 1
    fi

    ### Numero dei Worker Nodes
    count_workers=$(whiptail --title "Number of Working Nodes" \
        --inputbox "Select the number of Working Node (from 1 up to 10):" $(stty size) \
        "2" \
        3>&1 1>&2 2>&3)
    if ! validate_range "$count_workers" "0" "11"; then
        clear
        echo -e "\nInvalid Option!\n"
        exit 1
    fi
    
    ### IP dei Master Nodes
    for (( c=1; c<=$count_masters; c++ ))
    do
        master_ips[$c]=$(whiptail --title "Master Node n°$c IP" \
            --inputbox "Type the IP of the Master Node n°$c (which should be this node)." $(stty size) \
            "192.168.0.10" \
            3>&1 1>&2 2>&3)
    done

    ### IP dei Worker Nodes
    for (( c=1; c<=$count_workers; c++ ))
    do
        worker_ips[$c]=$(whiptail --title "Worker Node n°$c IP" \
            --inputbox "Type the IP of the Working Node n°$c:" $(stty size) \
            "${master_ips[1]}" \
            3>&1 1>&2 2>&3)
    done

    ### IP del Load Balancer
    lb_ip=$(whiptail --title "KeepAliveD VIP" \
            --inputbox "Please enter the Virtual IP (VIP) that will be used to expose the control plane. (There should not be any device or VM on this IP)" $(stty size) \
            "${master_ips[1]}" \
            3>&1 1>&2 2>&3)

    ### IP Range per Load Balancers
    if (whiptail --title "IP Address Pool LoadBalancers" --yes-button "Min-Max" --no-button "CIDR" \
            --yesno "Specify the desired IP range for Load Balancers: either Min-Max or a full CIDR block." $(stty size)); then
        choose_cidr=false
        ip_min=$(whiptail --title "Enter the Load Balancer's minimum IP" \
            --inputbox "Type the min IP:" $(stty size) \
            "${master_ips[1]}" \
            3>&1 1>&2 2>&3)
        ip_max=$(whiptail --title "Enter the Load Balancer's maximum IP" \
            --inputbox "Type the max IP:" $(stty size) \
            "$ip_min" \
            3>&1 1>&2 2>&3)
    else
        choose_cidr=true
        lb_cidr=$(whiptail --title "Enter the CIDR for the Load Balancers" \
            --inputbox "Type the CIDR for the Load Balancers:" $(stty size) \
            "${master_ips[1]}/25" \
            3>&1 1>&2 2>&3)
    fi

    ### Username per SSH
    username=$(whiptail --title "Username for SSH" \
        --inputbox "Type the username for the SSH connection with the VMs (non-root user):" $(stty size) \
        "username" \
        3>&1 1>&2 2>&3)

    ### Password per SSH
    passwd=$(whiptail --title "Password for SSH" \
        --passwordbox "Type the password for the SSH connection with the VMs (non-root user):" $(stty size) "" \
        3>&1 1>&2 2>&3)

    # -- 3 Input dei tool adoperati per il cluster ---

    ## CRI
    cri=$(whiptail --title "Container Runtime Interface" \
        --menu "Select which CNI you wanna use:" $(stty size) 3 \
        "Docker" "The most widely adopted and well-documented container runtime, it allows for simple container management." \
        "Containerd" "Highly adopted, minimal container runtime." \
        "CRI-O" "A lightweight, Kubernetes-specific container runtime." \
        3>&1 1>&2 2>&3)

    confirmMenuStacked
}

# --- Confirmation Menu Function Non-HA ---
function confirmMenuStacked {

    text_masters=""
    for (( c=1; c<=$count_masters; c++ ))
    do
        text_masters+="\nIP Master n°$c: ${master_ips[$c]}\n"
    done

    text_workers=""
    for (( c=1; c<=$count_workers; c++ ))
    do
        text_workers+="\nIP Worker n°$c: ${worker_ips[$c]}\n"
    done

    show_range=""
    if [[ "$choose_cidr" == "true" ]]; then
        show_range="$lb_cidr"
    else
        show_range="$ip_min-$ip_max"
    fi

    ### RECAP
    whiptail --title "Configuration Overview" \
            --msgbox "Adopted configuration: Stacked Configuration (HA)\n
            Number of Master Nodes: $count_masters\n
            Number of Working Nodes: $count_workers\n
            $text_masters
            $text_workers
            IP del Load Balancer KeepAliveD: $lb_ip\n
            IPAddressPool for LB: $show_range\n
            Container Runtime: $cri\n
            Credentials SSH non-ROOT:
            Username: $username
            Password: $passwd
            " $(stty size)

    if (whiptail --title "Final Confirmation" \
                --yesno "Do you confirm these settings to proceed with the installation?" $(stty size)); then
        initStacked
    else
        clear
        mainMenu
    fi

}

# --- Initialization of a Stacked ETCD HA Cluster [~ 10 minutes] ---
function initStacked {

    ### --- Initialization ---

    clear
    log "Creating K8S Cluster with STACKED ETCD Configuration"

    ### Install Tools
    log "Installing all the necessary Tools"
    sudo apt update;
    sudo apt install sshpass -y;
    sudo apt install software-properties-common -y;
    sudo add-apt-repository --yes --update ppa:ansible/ansible;
    sudo apt install ansible -y;

    ### Enabling Scripts (Bash)
    chmod +x Config/init.sh Config/Stacked/*

    ### Inventory
    inventoryStacked

    ### Ping Test
    log "Testing the Connectivity to all the Nodes"
    ansible all_vms -m ping;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} Some VMs are not reachable by Ansible! ${NC}${RED}ABORT.${NC}"
        log "ERROR: Some VMs are not reachable by Ansible!"
        abortExec
    fi

    ### Check if nodes are already part of a K8S Cluster 
    log "Testing if the Nodes are already part of a K8S Cluster"
    for node in $(ansible all_vms --list-hosts | grep -v 'hosts'); do
        ansible $node -b -m shell -a "kubectl get nodes" -e 'ansible_python_interpreter=/usr/bin/python3'
        
        if [ $? -eq 0 ]; then
            echo "${NC}${RED}ERRORE:${NC} The node with IP '$node' seems to be already part of a K8S Cluster! ${NC}${RED}ABORT.${NC}"
            log "ERROR: The node with IP '$node' seems to be already part of a K8S Cluster!"
            abortExec
        fi
    done

    ### Playbook w// init.sh
    log "Initiating all the Nodes"
    ansible-playbook ./Config/Stacked/playbook_init.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} Something went wrong initiating the nodes! ${NC}${RED}ABORT.${NC}"
        log "ERROR: Something went wrong initiating the nodes!"
        abortExec
    fi

    ### Setup the Network for Load Balancing
    network_interface="$(ip a | grep ${master_ips[1]} | awk '{ print $NF }')";
    echo $network_interface;
    ip add add $lb_ip/32 dev $network_interface

    ### --- Creation ---

    ### Creating the Cluster
    log "Creating the cluster with Kubeadm"
    ./Config/Stacked/stackedinit.sh ${master_ips[1]} $cri $lb_ip $username
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} Something went wrong initiating the cluster with Kubeadm! ${NC}${RED}ABORT.${NC}"
        log "ERROR: Something went wrong initiating the cluster with Kubeadm!"
        abortExec
    fi

    ### --- Join + Setup ---

    ### Load Certificates
    log "Loading the Certificates to all the Master Nodes"
    loadCerts

    ### Join Nodes
    partial_join_command="$(kubeadm token create --print-join-command)";
    case $cri in
        "Docker")
            JOIN_COMMAND_MASTER="$partial_join_command --cri-socket unix:///var/run/cri-dockerd.sock --control-plane";
            JOIN_COMMAND="$partial_join_command --cri-socket unix:///var/run/cri-dockerd.sock";
            ;;
        "Containerd")
            JOIN_COMMAND_MASTER="$partial_join_command --cri-socket unix:///run/containerd/containerd.sock --control-plane";
            JOIN_COMMAND="$partial_join_command --cri-socket unix:///run/containerd/containerd.sock";
            ;;
        "CRI-O")
            JOIN_COMMAND_MASTER="$partial_join_command --cri-socket unix:///var/run/crio/crio.sock --control-plane";
            JOIN_COMMAND="$partial_join_command --cri-socket unix:///var/run/crio/crio.sock";
            ;;
        *)
            clear
            echo -e "\nInvalid Option!\n"
            ;;
    esac

    ### Playbook for Joining
    log "Joining all the Nodes in the Cluster"
    ansible-playbook ./Config/Stacked/playbook_join.yaml -e "JOIN_COMMAND='$JOIN_COMMAND' JOIN_COMMAND_MASTER='$JOIN_COMMAND_MASTER'";
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} Something went wrong Joining the Nodes in the Cluster! ${NC}${RED}ABORT.${NC}"
        log "ERROR: Something went wrong Joining the Nodes in the Cluster!"
        abortExec
    fi

    # --- KubeConfig Setup ---
    for (( c=2; c<=$count_masters; c++ ))
    do
        sshpass -p $passwd ssh -o StrictHostKeyChecking=no $username@${master_ips[$c]} "echo $passwd | sudo -S mkdir -p $HOME/.kube"
        sshpass -p $passwd ssh -o StrictHostKeyChecking=no $username@${master_ips[$c]} "echo $passwd | sudo -S cp -i /etc/kubernetes/admin.conf $HOME/.kube/config"
        sshpass -p $passwd ssh -o StrictHostKeyChecking=no $username@${master_ips[$c]} "echo $passwd | sudo -S chown $(id -u):$(id -g) $HOME/.kube/config"
    done

    # --- KeepAliveD Installation ---

    ### IPAddressPool for MetalLB
    KEEPALIVED_CONFIGURATION_MASTER="
global_defs {
    vrrp_version 2
    vrrp_garp_master_delay 1
    vrrp_garp_master_refresh 60
    script_user root
    enable_script_security
}

vrrp_script chk_script {
    script \"/usr/bin/curl --silent --max-time 30 --insecure https://127.0.0.1:6443/readyz -o /dev/null\"
    interval 20 # check every 3 second
    fall 3 # require 2 failures for OK
    rise 2 # require 2 successes for OK
}

vrrp_instance lb-vips {
    state BACKUP
    interface ${network_interface}
    virtual_router_id 206
    priority 100
    advert_int 1
    nopreempt # Prevent fail-back
    track_script {
        chk_script
    }
    authentication {
        auth_type PASS
        auth_pass password
    }
    virtual_ipaddress {
        ${lb_ip}/32 dev ${network_interface}
    }
}
"

    cat <<EOF > keepalived.conf
$KEEPALIVED_CONFIGURATION_MASTER
EOF
    mv keepalived.conf Config/Stacked/

    ### Configure KeepAliveD on Master Nodes
    log "Installing and Configuring KeepAliveD"
    ansible-playbook ./Config/Stacked/playbook_vip.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} There were some problems and the KeepAliveD was NOT proprely configured ${NC}${RED}ABORT.${NC}"
        log "ERROR: Something went wrong Joining the Nodes in the Cluster!"
        abortExec
    fi

    #ip add del $lb_ip/32 dev $network_interface; 

    # --- Tools Configuration ---
    log "Installing all additional Tools for the Cluster"
    ./Config/Stacked/keepmaster.sh $cri

    ### IPAddressPool for MetalLB
    cat <<-EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: first-pool
    namespace: metallb-system
spec:
    addresses:
    - $show_range
    autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: l2
    namespace: metallb-system
spec:
    ipAddressPools:
    - first-pool
---
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
    name: example
    namespace: metallb-system
spec:
    ipAddressPools:
    - first-pool
EOF

    ### Final Message
    log "Installation and Configuration are done!"
    echo -e "\n${NC}${GREEN}#######################################################################################${NC}\n"
    echo -e "\n Installation and Configuration are done! Check your cluster using the 'k9s' command.\n"
    echo -e "\n${NC}${GREEN}#######################################################################################${NC}\n"
}

############################################################################################################################
##                                            Executive Section                                                           ##
############################################################################################################################

mkdir /var/log/kinit/
touch /var/log/kinit/kinit.logs
clear
mainMenu