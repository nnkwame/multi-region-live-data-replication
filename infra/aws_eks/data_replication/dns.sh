#!/usr/bin/env bash
# Register <project_name>.ironlabs.online and point it at this cluster's
# ingress NLB. Run AFTER ./up.sh <name> and after deploying an Ingress
# (e.g. the bagisto overlay); it waits for the NLB hostname to exist.
# Usage: ./dns.sh <project-name>      e.g.  ./dns.sh kwames-store-a
source "$(dirname "${BASH_SOURCE[0]}")/scripts/common.sh"

NAME="${1:-}"
validate_name dns.sh "$NAME"
CLUSTER_NAME="eks-${NAME}"

require_tools terraform aws kubectl
require_aws_credentials
tf_init
select_workspace "$NAME" existing

log "Connecting kubectl to your cluster..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" --alias "$CLUSTER_NAME" >/dev/null

log "Waiting for the ingress controller NLB to get a hostname (up to 10 min)..."
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  svc/ingress-nginx-controller -n ingress-nginx --timeout=600s >/dev/null

log "Creating/updating the DNS record in Terraform..."
terraform apply -input=false -auto-approve \
  -var "project_name=${NAME}" -var "region=${REGION}" \
  -var "enable_domain_record=true"

log "Done. Your app domain (propagates in ~60s):"
terraform output -raw app_domain
