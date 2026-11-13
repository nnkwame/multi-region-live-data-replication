#!/usr/bin/env bash
# Deploy Kafka Connect after building/loading the pinned local image.
set -euo pipefail
context="${1:-minikube}"
if [[ "$context" != minikube ]]; then
  echo 'This local deployment script only permits the minikube context.' >&2
  exit 1
fi
kubectl --context="$context" apply --server-side -k k8s/data_replication/connect-local
kubectl --context="$context" -n data-replication annotate kafkaconnect my-connect-cluster strimzi.io/pause-reconciliation- 2>/dev/null || true
kubectl --context="$context" -n data-replication wait kafkaconnect/my-connect-cluster --for=condition=Ready --timeout=600s
