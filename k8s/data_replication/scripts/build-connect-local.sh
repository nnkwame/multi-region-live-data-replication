#!/usr/bin/env bash
# Build and load the Strimzi-generated connector image into Minikube.
set -euo pipefail
image=capstone-connect:3.7.1-kafka-4.3.1
docker build -t "$image" k8s/data_replication/connect
minikube -p minikube image load "$image"
