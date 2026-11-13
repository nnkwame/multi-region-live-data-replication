#!/usr/bin/env bash
# Deploy the local standalone monitoring trial.
set -euo pipefail
context="${1:-minikube}"
if [[ "$context" != minikube ]]; then
  echo 'This local deployment script only permits the minikube context.' >&2
  exit 1
fi
kubectl --context="$context" apply --server-side -k k8s/data_replication/monitoring/local
kubectl --context="$context" -n data-replication rollout status deployment/capstone-prometheus --timeout=180s
kubectl --context="$context" -n data-replication rollout status deployment/capstone-grafana --timeout=180s
kubectl --context="$context" -n data-replication rollout status daemonset/capstone-node-exporter --timeout=180s
