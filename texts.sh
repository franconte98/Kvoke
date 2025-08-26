#!/bin/bash

# shellcheck disable=SC2046
WELCOME_MESSAGE=$(cat <<'EOF'
This script will guide you through the initial setup and preliminary configuration of a Kubernetes cluster.
This IaC script suite automates Kubernetes cluster installation and configuration. 
It includes three official node-joining configurations, adaptable to your available infrastructure.

VM Prerequisites:
- Each VM requires a unique IP address.
- All VMs must reside on the same network (and must be reachable for each other).
- At least 2vCPU, 2Gi of TAM and 40Gb of storage for each VM.
- All the VMs got to have the same sudoer user (With the same username and password).
EOF
)

WELCOME_1=$(cat <<'EOF'
This cluster configuration requires less infrastructure, but it's less focused on high availability (NON-HA). [~ 10 minutes to create it]

MINIMUM REQUIREMENTS:
- 1 Master Node
- 1, up to 10 Worker Nodes
NETWORK PREREQUISITES:
- Each VM requires a unique IP address.
- All VMs must reside on the same network (and must be reachable for each other).
- At least 2vCPU, 2Gi of RAM and 40Gb of Storage for each VM.
- All the VMs got to have the same sudoer user (With the same username and password).
EOF
)