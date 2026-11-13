#!/usr/bin/env bash
# First run on a fresh local Kafka/Connect deployment with quiescent stores.
set -euo pipefail
context="${1:-minikube}"
if [[ "$context" != minikube ]]; then echo 'Only minikube is supported.' >&2; exit 1; fi
ns=data-replication
if kubectl --context="$context" -n "$ns" get kafkaconnector my-source-connector >/dev/null 2>&1 || \
   kubectl --context="$context" -n "$ns" get kafkaconnector my-sink-connector >/dev/null 2>&1; then
  echo 'Connectors already exist. Inspect their offsets and state before starting another run.' >&2
  exit 1
fi
count_orders() {
  kubectl --context="$context" -n "$1" exec mariadb-0 -- sh -c \
    'MYSQL_PWD="$MARIADB_PASSWORD" mariadb -h 127.0.0.1 -u "$MARIADB_USER" "$MARIADB_DATABASE" -N -e "SELECT COUNT(*) FROM orders"'
}
source_count=$(count_orders store-a)
target_count=$(count_orders store-b)
if [[ "$source_count" -le 0 || "$target_count" -ne 0 ]]; then
  echo "Expected a populated A and order-free B; found A=$source_count B=$target_count." >&2
  exit 1
fi
# Topics/offsets left from prior tests can replay stale data; this script does not reset them.
topics=$(kubectl --context="$context" -n "$ns" exec my-cluster-dual-role-0 -- \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list)
if printf '%s\n' "$topics" | grep -q '^store-a\.'; then
  echo 'Existing source topics found. Inspect and deliberately prepare a fresh run.' >&2
  exit 1
fi
kubectl --context="$context" -n "$ns" apply --server-side -f k8s/data_replication/connect/debezium_src.yml
# Orders have customer foreign keys; both stores must start with matching customers.
# Catch up parent orders before subscribing to items, addresses and other child tables.
sed 's/^    topics.regex: .*/    topics: "store-a.bagisto.orders"/' \
  k8s/data_replication/connect/jdbc_sink.yml | kubectl --context="$context" -n "$ns" apply --server-side -f -
for ((attempt=0; attempt<180; attempt++)); do
  target_count=$(count_orders store-b)
  echo "Order rows: A=$source_count B=$target_count"
  if [[ "$target_count" -eq "$source_count" ]]; then break; fi
  if [[ "$target_count" -gt "$source_count" || "$attempt" -eq 179 ]]; then
    echo 'Order count did not converge. Inspect connector tasks and the dead-letter queue.' >&2
    exit 1
  fi
  sleep 5
done
kubectl --context="$context" -n "$ns" apply --server-side -f k8s/data_replication/connect/jdbc_sink.yml
echo 'Parent orders caught up; full captured-table sink enabled. Verify all tables, DLQ, and ongoing CDC.'
