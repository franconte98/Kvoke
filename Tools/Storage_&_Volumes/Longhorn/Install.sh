#!/bin/bash

## Installazione Helm di Longhorn
helm repo add longhorn https://charts.longhorn.io;
helm repo update;

Version_Latest=$(curl --silent -qI https://github.com/longhorn/longhorn/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}');
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version $Version_Latest;