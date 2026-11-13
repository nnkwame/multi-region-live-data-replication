#!/usr/bin/env bash
# Install the pinned Strimzi operator into the local Minikube context.
set -euo pipefail
context="${1:-minikube}"
if [[ "$context" != minikube ]]; then
  echo 'This local installation script only permits the minikube context.' >&2
  exit 1
fi
namespace=data-replication
version=1.3.1
expected=557c1452cbf58f80714858b25203cb644de5b15edb1e9adf6bf7fcf8b22a1931
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --retry 3 -o "$tmp/operator.yaml" "https://github.com/strimzi/strimzi-kafka-operator/releases/download/${version}/strimzi-cluster-operator-${version}.yaml"
printf '%s  %s\n' "$expected" "$tmp/operator.yaml" | sha256sum -c -
kubectl --context="$context" create namespace "$namespace" --dry-run=client -o yaml | kubectl --context="$context" apply -f -
sed 's/namespace: myproject/namespace: data-replication/g' "$tmp/operator.yaml" > "$tmp/operator-local.yaml"
kubectl --context="$context" -n "$namespace" apply --server-side -f "$tmp/operator-local.yaml"
kubectl --context="$context" -n "$namespace" rollout status deployment/strimzi-cluster-operator --timeout=300s
