#!/usr/bin/env bash
# Deploy the local Kafka node pool and broker with the Strimzi JMX exporter.
set -euo pipefail
context="${1:-minikube}"
if [[ "$context" != minikube ]]; then
  echo 'This local deployment script only permits the minikube context.' >&2
  exit 1
fi
kubectl --context="$context" -n data-replication apply --server-side \
  -f k8s/data_replication/kafka/metrics-config.yml \
  -f k8s/data_replication/kafka/kafka.yml
kubectl --context="$context" -n data-replication wait kafka/my-cluster --for=condition=Ready --timeout=600s
