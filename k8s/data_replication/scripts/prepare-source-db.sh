#!/usr/bin/env bash
# Configure the local source database for Debezium. Restarts MariaDB once.
set -euo pipefail
context="${1:-minikube}"
if [[ "$context" != minikube ]]; then
  echo 'This local setup script only permits the minikube context.' >&2
  exit 1
fi
kubectl --context="$context" apply --server-side -k k8s/overlays/a/bagisto_db
kubectl --context="$context" -n store-a rollout status statefulset/mariadb --timeout=180s
kubectl --context="$context" -n store-a exec mariadb-0 -- sh -c '
  MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -h 127.0.0.1 -u root <<"SQL"
CREATE USER IF NOT EXISTS '\''debezium'\''@'\''%'\'' IDENTIFIED BY '\''debezium'\'';
ALTER USER '\''debezium'\''@'\''%'\'' IDENTIFIED BY '\''debezium'\'';
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '\''debezium'\''@'\''%'\'';
SHOW VARIABLES WHERE Variable_name IN ('\''log_bin'\'', '\''binlog_format'\'', '\''binlog_row_image'\'', '\''server_id'\'');
SQL
'
