#!/bin/bash

### Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts;
helm install prometheus prometheus-community/prometheus --namespace monitoring --create-namespace;

### Graphana 
helm repo add grafana https://grafana.github.io/helm-charts;
helm install grafana grafana/grafana --namespace monitoring;

echo "Grafana Password:";
Secret="$(kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode)";
echo $Secret;