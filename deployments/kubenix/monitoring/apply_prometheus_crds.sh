#!/bin/bash
# need to be applied manually b/c helm + kubenix cannot handle them
# https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md
# VERSION MUST MATCH VERISON OF KUBE_PROMETHEUS_STACK CHARTS IN USE

kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.87.1/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.87.1/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.87.1/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.87.1/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.87.1/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.87.1/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.87.1/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.87.1/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.87.1/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.87.1/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
