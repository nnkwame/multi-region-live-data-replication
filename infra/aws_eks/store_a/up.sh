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

log "Installing cert-manager (Let's Encrypt, DNS-01 via Route53 IRSA)..."
kubectl apply -f "${K8S_DIR}/cert-manager/cert-manager.yaml"
kubectl wait --for=condition=Available deployment/cert-manager deployment/cert-manager-webhook \
  deployment/cert-manager-cainjector -n cert-manager --timeout=300s >/dev/null
IRSA_ROLE_ARN="$(terraform output -raw cert_manager_irsa_role_arn)"
kubectl annotate serviceaccount cert-manager -n cert-manager \
  "eks.amazonaws.com/role-arn=${IRSA_ROLE_ARN}" --overwrite >/dev/null
# IRSA is resolved at pod start; roll so the running cert-manager picks it up.
kubectl rollout restart deployment/cert-manager -n cert-manager >/dev/null
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=300s >/dev/null
kubectl apply -f "${K8S_DIR}/cert-manager/cluster-issuer.yml"

log "Done! Your nodes:"
kubectl get nodes -o wide
echo
log "Next: deploy the app overlay. Traffic arrives via https://kwamesdemostore.ironlabs.online (see demo_dns/cutover.sh)."
log "Remember to run ./down.sh ${NAME} when you're finished; the cluster costs money every hour it's up."
