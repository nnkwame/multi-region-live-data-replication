#!/usr/bin/env bash
# Create (or update) your EKS cluster.
# Usage: ./up.sh <project-name>      e.g.  ./up.sh kwames-store-a
source "$(dirname "${BASH_SOURCE[0]}")/scripts/common.sh"

NAME="${1:-}"
validate_name up.sh "$NAME"
CLUSTER_NAME="eks-${NAME}"

require_tools terraform aws kubectl
require_aws_credentials
tf_init
select_workspace "$NAME" create
TF_VARS=(-var "project_name=${NAME}" -var "region=${REGION}")

# Preserve an already-created DNS record (dns.sh) across re-applies.
if terraform state list 2>/dev/null | grep -q '^aws_route53_record\.'; then
  TF_VARS+=(-var "enable_domain_record=true")
fi

log "Building ${CLUSTER_NAME}. This takes about 15 minutes, go get a coffee."
terraform apply -input=false -auto-approve "${TF_VARS[@]}"

log "Connecting kubectl to your cluster..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" --alias "$CLUSTER_NAME" >/dev/null

log "Waiting for nodes to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s >/dev/null

log "Installing the nginx ingress controller (pinned manifest)..."
kubectl apply -f "${K8S_DIR}/nginx-ingress/deploy.yaml"
kubectl wait --for=condition=Available deployment/ingress-nginx-controller \
  -n ingress-nginx --timeout=300s >/dev/null

log "Done! Your nodes:"
kubectl get nodes -o wide
echo
log "Next: deploy the app overlay, then run ./dns.sh ${NAME} to register the domain."
log "Remember to run ./down.sh ${NAME} when you're finished; the cluster costs money every hour it's up."
