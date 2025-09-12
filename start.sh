#!/bin/bash

### --- Import Environments---
source ./environment.sh

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

# --- Confirmation Menu Function for Creating Clusters ---
function confirmCreate {

    # --- Filter the type of configuration ---
    case $CONF_CHOICE in
        1)
            dialog_text=""
            for (( c=1; c<=$count_workers; c++ ))
            do
                dialog_text+="IP Worker n°$c: ${worker_ips[$c]}\n"
            done

            show_range=""
            if [[ "$choose_cidr" == "true" ]]; then
                show_range="$lb_cidr"
            else
                show_range="$ip_min-$ip_max"
            fi

            # --- Call to the environment function ---
            confirm_page

            # --- Graphical Recap ---
            whiptail --title "Configuration Overview" \
                    --msgbox "$CONFIRM" 30 80
            
            # --- Final Confirm ---
            if (whiptail --title "Final Confirmation" \
                        --yesno "Do you confirm these settings to proceed with the installation?" 10 60); then
                initSimple
            else
                clear
                mainMenu
            fi
            ;;
        2)
            text_masters=""
            for (( c=1; c<=$count_masters; c++ ))
            do
                text_masters+="IP Master n°$c: ${master_ips[$c]}\n"
            done

            text_workers=""
            for (( c=1; c<=$count_workers; c++ ))
            do
                text_workers+="IP Worker n°$c: ${worker_ips[$c]}\n"
            done

            show_range=""
            if [[ "$choose_cidr" == "true" ]]; then
                show_range="$lb_cidr"
            else
                show_range="$ip_min-$ip_max"
            fi
            # --- Call to the environment function ---
            confirm_page

            # --- Graphical Recap ---
            whiptail --title "Configuration Overview" \
                    --msgbox "$CONFIRM" 45 80
            
            # --- Final Confirm ---
            if (whiptail --title "Final Confirmation" \
                        --yesno "Do you confirm these settings to proceed with the installation?" 10 60); then
                initStacked
            else
                clear
                mainMenu
            fi
            ;;
        *)
            clear
            echo -e "\nInvalid Option!\n"
            ;;
    esac
}

# --- Confirmation Menu Function Join ---
function confirmJoin {

    # --- Filter the type of configuration ---
    case $CHOICE_JOIN in
        1)
            # --- Call to the environment function ---
            confirm_page_join

            # --- Graphical Recap ---
            whiptail --title "Configuration Overview" \
                    --msgbox "$CONFIRM" 30 80
            
            # --- Final Confirm ---
            if (whiptail --title "Final Confirmation" \
                        --yesno "Do you confirm these settings to proceed with the installation?" 10 60); then
                initJoinWorker
            else
                clear
                mainMenu
            fi
            ;;
        *)
            clear
            echo -e "\nInvalid Option!\n"
            ;;
    esac

}

# --- Main Menu, here everything start! ---
function mainMenu {

    # --- 1. Welcome! ---
    whiptail --title "KINIT - the K8S OnPremise Cluster Initiator!" \
            --msgbox "$WELCOME_MESSAGE" 30 100

    # --- First Choice ---
    CHOICE=$(whiptail --title "Choose an Option" \
        --menu "Select what you wanna do right now." 20 70 2 \
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
##  Join Cluster  ##
####################

# --- Create Inventory Function ---
function inventoryJoin {
    
    rm -rf $OUTPUT_FILE;
    # Master
    echo "[master]" >> "$OUTPUT_FILE"
    echo "$ip_master" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # Node To Join
    echo "[join]" >> "$OUTPUT_FILE"
    echo "$ip_to_join" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # All IPs
    echo "[all_vms:children]" >> "$OUTPUT_FILE"
    echo "master" >> "$OUTPUT_FILE"
    echo "join" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # Credentials and Attributes
    echo "[all_vms:vars]" >> "$OUTPUT_FILE"
    echo "ansible_user=$username" >> "$OUTPUT_FILE"
    echo "ansible_ssh_pass=$passwd" >> "$OUTPUT_FILE"
    echo "ansible_become_pass=$passwd" >> "$OUTPUT_FILE"
    echo "master_ip=$ip_master" >> "$OUTPUT_FILE"
    echo "ip_to_join=$ip_to_join" >> "$OUTPUT_FILE"
    echo "cri=$cri" >> "$OUTPUT_FILE"
    echo "username=$username" >> "$OUTPUT_FILE"
    echo "passwd=$passwd" >> "$OUTPUT_FILE"

}

# --- Join Cluster Menu ---
# mainMenu -> joinMenu
function joinMenu {

    # --- Menu ---
    CHOICE_JOIN=$(whiptail --title "Join Node to a Cluster" \
        --menu "Choose which type of Node you wanna Join to the Cluster." 20 70 2 \
        "1" "Join a Worker Node" \
        "2" "Join a Master Node" \
        3>&1 1>&2 2>&3)

    # --- Routing w// switch ---
    case $CHOICE_JOIN in
        1)
            JoinWorkerMenu
            ;;
        2)
            JoinMasterMenu
            ;;
        *)
            clear
            echo -e "\nInvalid Option!\n"
            ;;
    esac
}

# --- Menu to Join a Worker Node ---
function JoinWorkerMenu {

    whiptail --title "Joining a Worker Node to a Kvoke Cluster" \
        --msgbox "$WELCOME_JOIN_1" 30 100

    ### Master Node's IP
    ip_master=$(whiptail --title "Select the Master Node's IP or VIP" \
        --inputbox "Type the IP of either the Primary Node or the associated VIP." 10 60 \
        "192.168.0.100" \
        3>&1 1>&2 2>&3)
    
    ### Master Node's IP
    ip_to_join=$(whiptail --title "Select the IP of the Node to Join" \
        --inputbox "Type the IP of the Node to Join as a Worker." 10 60 \
        "192.168.0.100" \
        3>&1 1>&2 2>&3)

    ### SSH Connection Username
    username=$(whiptail --title "Select the Username for the SSH Connection" \
        --inputbox "$USERNAME_MSG" 15 60 \
        "username" \
        3>&1 1>&2 2>&3)

    ### SSH Connection Passwords
    passwd=$(whiptail --title "Select the Password for the SSH Connection" \
        --passwordbox "$PASSWORD_MSG" 15 60 "" \
        3>&1 1>&2 2>&3)

    ## CRI Selection
    cri=$(whiptail --title "Select the Container Runtime Interface (CRI)" \
        --menu "Select which CRI you wanna use for each VM in the cluster:" 10 150 3 \
        "Docker" "The most widely adopted and well-documented container runtime, it allows for simple container management." \
        "Containerd" "Highly adopted, but minimal container runtime." \
        "CRI-O" "A lightweight, Kubernetes-specific container runtime." \
        3>&1 1>&2 2>&3)

    confirmJoin;
}

# --- Initialization of the Join Cluster ---
function initJoinWorker {
    
    ### --- Initialization ---

    clear
    log "Joining a WORKER Node to a Kvoke Cluster"

    ### Install Tools on the HOST
    log "Installing all the necessary Tools"
    sudo apt update -y;
    sudo apt install sshpass software-properties-common -y;
    sudo add-apt-repository --yes --update ppa:ansible/ansible;
    sudo apt install ansible -y;

    ### Enabling Scripts (Bash) on the HOST
    chmod +x Config/init.sh Config/Join/*

    ### Ansible Inventory creation
    inventoryJoin

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
    ansible-playbook ./Config/Join/playbook_init.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} There were some problems and the Initiation did not succeed. ${NC}${RED}ABORT.${NC}"
        log "ERROR: There were some problems and the Initiation did not succeed."
        abortExec
    fi

    ### Playbook for Joining
    log "Joining the Node"
    ansible-playbook ./Config/Join/playbook_join.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} There were some problems and the Worker Nodes did not join. ${NC}${RED}ABORT.${NC}"
        log "ERROR: There were some problems and the Worker Nodes did not join."
        abortExec
    fi

    ### Final Message
    log "Installation and Configuration are done!"
    echo -e "\n${NC}${GREEN}#######################################################################################${NC}\n"
    echo -e "\n Installation and Configuration are done! Check your cluster using the 'k9s' command in the VIP.\n"
    echo -e "\n${NC}${GREEN}#######################################################################################${NC}\n"
}

# --- Menu to Join a Master Node ---
function JoinMasterMenu {
    confirmJoin;
}

######################
##  Create Cluster  ##
######################

# --- Create Cluster Menu ---
# mainMenu -> createMenu
function createMenu {

    # --- First Option for Creation ---
    CONF_CHOICE=$(whiptail --title "Configuration Options" \
        --menu "Based on the documentation, select which configuration you wanna instantiate for your Kinit cluster." 20 70 3 \
        "1" "Simple Configuration (NON-HA)" \
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
    echo "show_range=$show_range" >> "$OUTPUT_FILE"

}

# createMenu -> menuSimple
function menuSimple {

    whiptail --title "Simple Configuration (NON-HA)" \
        --msgbox "$WELCOME_1" 30 100

    ### Number of Working Nodes
    count_workers=$(whiptail --title "Select the number of Working Nodes" \
        --inputbox "Type the desired number of Working Nodes for your cluster (from 1 up to 10)." 10 60 \
        "2" \
        3>&1 1>&2 2>&3)
    if ! validate_range "$count_workers" "0" "11"; then
        clear
        echo -e "\nInvalid Option!\n"
        exit 1
    fi

    ### Master Node's IP
    ip_master=$(whiptail --title "Select the Master Node's IP" \
        --inputbox "Type the IP of the desired Master Node for your cluster." 10 60 \
        "192.168.0.100" \
        3>&1 1>&2 2>&3)

    ### Worker Nodes's IP
    for (( c=1; c<=$count_workers; c++ ))
    do
        worker_ips[$c]=$(whiptail --title "Select the Worker Node n°$c IP" \
            --inputbox "Type the IP of the Working Node n°$c." 10 60 \
            "$ip_master" \
            3>&1 1>&2 2>&3)
    done

    ### IPAddressPool for MetalLB
    if (whiptail --title "IP Address Pool LoadBalancers" --yes-button "Min-Max" --no-button "CIDR" \
            --yesno "Specify the desired IP range for Load Balancers. You can type it either as a Min-Max or a full CIDR block." 10 60); then
        choose_cidr=false
        ip_min=$(whiptail --title "Select the Load Balancer's MINimum IP" \
            --inputbox "Type the minimum IP for your Cluster's Load Balancers." 10 60 \
            "$ip_master" \
            3>&1 1>&2 2>&3)
        ip_max=$(whiptail --title "Select the Load Balancer's MAXimum IP" \
            --inputbox "Type the maximum IP for your Cluster's Load Balancers." 10 60 \
            "$ip_min" \
            3>&1 1>&2 2>&3)
    else
        choose_cidr=true
        lb_cidr=$(whiptail --title "Select the CIDR for the Load Balancers" \
            --inputbox "Type the CIDR for the Cluster's Load Balancers." 10 60 \
            "$ip_master/25" \
            3>&1 1>&2 2>&3)
    fi

    ### SSH Connection Username
    username=$(whiptail --title "Select the Username for the SSH Connection" \
        --inputbox "$USERNAME_MSG" 15 60 \
        "username" \
        3>&1 1>&2 2>&3)

    ### SSH Connection Passwords
    passwd=$(whiptail --title "Select the Password for the SSH Connection" \
        --passwordbox "$PASSWORD_MSG" 15 60 "" \
        3>&1 1>&2 2>&3)

    ## CRI Selection
    cri=$(whiptail --title "Select the Container Runtime Interface (CRI)" \
        --menu "Select which CRI you wanna use for each VM in the cluster:" 10 150 3 \
        "Docker" "The most widely adopted and well-documented container runtime, it allows for simple container management." \
        "Containerd" "Highly adopted, but minimal container runtime." \
        "CRI-O" "A lightweight, Kubernetes-specific container runtime." \
        3>&1 1>&2 2>&3)

    confirmCreate
}

# --- Initialization of a Simple NON-HA Cluster [~ 10 minutes] ---
function initSimple {

    ### --- Initialization ---

    clear
    log "Creating K8S Cluster with SIMPLE Configuration"

    ### Install Tools on the HOST
    log "Installing all the necessary Tools"
    sudo apt update -y;
    sudo apt install sshpass software-properties-common -y;
    sudo add-apt-repository --yes --update ppa:ansible/ansible;
    sudo apt install ansible -y;

    ### Enabling Scripts (Bash) on the HOST
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
    ansible-playbook ./Config/Simple/playbook_init.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} There were some problems and the Initiation did not succeed. ${NC}${RED}ABORT.${NC}"
        log "ERROR: There were some problems and the Initiation did not succeed."
        abortExec
    fi

    ### --- Creation ---

    ### Creating the Cluster
    log "Creating the Cluster and Installing all the additional tools for the Cluster"
    ansible-playbook ./Config/Simple/playbook_create.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} Something went wrong initiating the cluster with Kubeadm! ${NC}${RED}ABORT.${NC}"
        log "ERROR: Something went wrong initiating the cluster with Kubeadm!"
        abortExec
    fi

    ### --- Join + Setup LB ---

    ### Playbook for Joining
    log "Joining all the Nodes"
    ansible-playbook ./Config/Simple/playbook_join.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} There were some problems and the Worker Nodes did not join. ${NC}${RED}ABORT.${NC}"
        log "ERROR: There were some problems and the Worker Nodes did not join."
        abortExec
    fi

    ### IPAddressPool for MetalLB
    log "Adding the Load Balancer Range."
    ansible-playbook ./Config/Simple/playbook_lb.yaml;

    ### End Of Process
    log "Installation and Configuration are done!"
    echo -e "\n${NC}${GREEN}#######################################################################################${NC}\n"
    echo -e "\n Installation and Configuration are done! Check your cluster using the 'k9s' command in the Master Node.\n"
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
    echo "show_range=$show_range" >> "$OUTPUT_FILE"

}

# --- Menu Stacked Configuration ---
function menuStacked {

    whiptail --title "Stacked Configuration Cluster Setup" \
        --msgbox "$WELCOME_2" 30 100

    ### Number of Master Nodes
    count_masters=$(whiptail --title "Select the number of Master Nodes" \
        --inputbox "Type the desired number of Master Nodes (from 3 up to 7). An Odd number is strongly advised." 10 60 \
        "3" \
        3>&1 1>&2 2>&3)
    if ! validate_range "$count_masters" "2" "8"; then
        clear
        echo -e "\nInvalid Option!\n"
        exit 1
    fi

    ### Number of Worker Nodes
    count_workers=$(whiptail --title "Select the number of Working Nodes" \
        --inputbox "Type the desired number of Working Nodes for your cluster (from 1 up to 10)." 10 60 \
        "2" \
        3>&1 1>&2 2>&3)
    if ! validate_range "$count_workers" "0" "11"; then
        clear
        echo -e "\nInvalid Option!\n"
        exit 1
    fi
    
    ### Master's Nodes IP
    for (( c=1; c<=$count_masters; c++ ))
    do
        master_ips[$c]=$(whiptail --title "Select the Master Node's IP n°$c IP" \
            --inputbox "Type the IP of the Master Node n°$c." 10 60 \
            "192.168.0.10" \
            3>&1 1>&2 2>&3)
    done

    ### Worker Node's IP
    for (( c=1; c<=$count_workers; c++ ))
    do
        worker_ips[$c]=$(whiptail --title "Select the Worker Node's IP n°$c IP" \
            --inputbox "Type the IP of the Working Node n°$c:" 10 60 \
            "${master_ips[1]}" \
            3>&1 1>&2 2>&3)
    done

    ### VIP for KeepAliveD
    lb_ip=$(whiptail --title "KeepAliveD VIP" \
            --inputbox "Please enter the Virtual IP (VIP) that will be used to expose the control plane. (There should not be any device or VM on this IP)" 15 60 \
            "${master_ips[1]}" \
            3>&1 1>&2 2>&3)

    ### IP Range per Load Balancers
    if (whiptail --title "IP Address Pool LoadBalancers" --yes-button "Min-Max" --no-button "CIDR" \
            --yesno "Specify the desired IP range for Load Balancers. You can type it either as a Min-Max or a full CIDR block." 10 60); then
        choose_cidr=false
        ip_min=$(whiptail --title "Select the Load Balancer's MINimum IP" \
            --inputbox "Type the minimum IP for your Cluster's Load Balancers." 10 60 \
            "${master_ips[1]}" \
            3>&1 1>&2 2>&3)
        ip_max=$(whiptail --title "Select the Load Balancer's MAXimum IP" \
            --inputbox "Type the maximum IP for your Cluster's Load Balancers." 10 60 \
            "$ip_min" \
            3>&1 1>&2 2>&3)
    else
        choose_cidr=true
        lb_cidr=$(whiptail --title "Select the CIDR for the Load Balancers" \
            --inputbox "Type the CIDR for the Cluster's Load Balancers." 10 60 \
            "${master_ips[1]}/25" \
            3>&1 1>&2 2>&3)
    fi

    ### Username per SSH
    username=$(whiptail --title "Select the Username for the SSH Connection" \
        --inputbox "$USERNAME_MSG" 15 60 \
        "username" \
        3>&1 1>&2 2>&3)

    ### Password per SSH
    passwd=$(whiptail --title "Select the Password for the SSH Connection" \
        --passwordbox "$PASSWORD_MSG" 15 60 "" \
        3>&1 1>&2 2>&3)

    # -- 3 Input dei tool adoperati per il cluster ---

    ## CRI
    cri=$(whiptail --title "Container Runtime Interface" \
        --menu "Select which CNI you wanna use:" 10 150 3 \
        "Docker" "The most widely adopted and well-documented container runtime, it allows for simple container management." \
        "Containerd" "Highly adopted, minimal container runtime." \
        "CRI-O" "A lightweight, Kubernetes-specific container runtime." \
        3>&1 1>&2 2>&3)

    confirmCreate
}

# --- Initialization of a Stacked ETCD HA Cluster [~ 15 minutes] ---
function initStacked {

    ### --- Initialization ---

    clear
    log "Creating K8S Cluster with STACKED ETCD Configuration"

    ### Install Tools on the HOST
    log "Installing all the necessary Tools"
    sudo apt update;
    sudo apt install sshpass -y;
    sudo apt install software-properties-common -y;
    sudo add-apt-repository --yes --update ppa:ansible/ansible;
    sudo apt install ansible -y;

    ### Enabling Scripts (Bash) on the HOST
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

    ### Setup the Network for KeepAliveD
    ansible-playbook ./Config/Stacked/playbook_set_net.yaml;

    ### --- Creation ---

    ### Creating the Cluster
    log "Creating the cluster with Kubeadm"
    ansible-playbook ./Config/Stacked/playbook_create.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} Something went wrong initiating the cluster with Kubeadm! ${NC}${RED}ABORT.${NC}"
        log "ERROR: Something went wrong initiating the cluster with Kubeadm!"
        abortExec
    fi

    ### --- Join + Setup ---

    ### Load Certificates
    log "Loading the Certificates to all the Master Nodes"
    ansible-playbook ./Config/Stacked/playbook-loadcerts.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} Something went wrong transfering the certs to the other masters! ${NC}${RED}ABORT.${NC}"
        log "ERROR: Something went wrong transfering the certs to the other masters!"
        abortExec
    fi

    ### Playbook for Joining
    log "Joining all the Nodes in the Cluster"
    ansible-playbook ./Config/Stacked/playbook_join.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} Something went wrong Joining the Nodes in the Cluster! ${NC}${RED}ABORT.${NC}"
        log "ERROR: Something went wrong Joining the Nodes in the Cluster!"
        abortExec
    fi

    # --- KubeConfig Setup ---
    log "Passing the KubeConfigs"
    ansible-playbook ./Config/Stacked/playbook_kubeconfig.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} There were some problems passing the KubeConfigs! ${NC}${RED}ABORT.${NC}"
        log "ERROR: There were some problems passing the KubeConfigs!"
        abortExec
    fi

    ### Configure KeepAliveD on Master Nodes
    log "Installing and Configuring KeepAliveD"
    ansible-playbook ./Config/Stacked/playbook_vip.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} There were some problems and the KeepAliveD was NOT proprely configured ${NC}${RED}ABORT.${NC}"
        log "ERROR: There were some problems and the KeepAliveD was NOT proprely configured"
        abortExec
    fi

    # --- Tools Configuration ---
    log "Installing all additional Tools for the Cluster"
    ansible-playbook ./Config/Stacked/playbook_tools.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} There were some problems installing the tools! ${NC}${RED}ABORT.${NC}"
        log "ERROR: There were some problems installing the tools!"
        abortExec
    fi

    ### IPAddressPool for MetalLB
    log "Adding the Load Balancer Range."
    ansible-playbook ./Config/Stacked/playbook_lb.yaml;
    if [ $? -ne 0 ]; then
        echo "${NC}${RED}ERROR:${NC} There were some problems adding the Load Balancer Range! ${NC}${RED}ABORT.${NC}"
        log "ERROR: There were some problems adding the Load Balancer Range!"
        abortExec
    fi

    ### Final Message
    log "Installation and Configuration are done!"
    echo -e "\n${NC}${GREEN}#######################################################################################${NC}\n"
    echo -e "\n Installation and Configuration are done! Check your cluster using the 'k9s' command in the VIP.\n"
    echo -e "\n${NC}${GREEN}#######################################################################################${NC}\n"
}

############################################################################################################################
##                                            Executive Section                                                           ##
############################################################################################################################

mkdir /var/log/kvoke/
touch /var/log/kvoke/kvoke.logs
clear
mainMenu