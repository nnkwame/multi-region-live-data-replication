#!/usr/bin/env bash
# Flip kwamesdemostore.ironlabs.online between store A and store B.
#
# The demo URL is deliberately NOT managed by Terraform (so per-stack applies
# can never fight over it). This script talks to Route53 directly with the AWS
# CLI, as requested:
#   ./cutover.sh a       -> demo URL points at store A's cluster ingress NLB
#   ./cutover.sh b       -> demo URL points at store B's cluster ingress NLB
#   ./cutover.sh delete  -> removes the demo URL record (run before teardown)
#
# It discovers each cluster's ingress NLB by the Kubernetes tags the in-tree
# cloud provider applies, so it needs no Terraform state access.
set -euo pipefail

export AWS_PAGER=""

DEMO_NAME="kwamesdemostore.ironlabs.online"
ZONE_NAME="ironlabs.online"

log() { printf '\033[1;34m>>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

TARGET="${1:-}"
case "$TARGET" in
  a)      CLUSTER="eks-kwames-store-a";      REGION="us-east-1" ;;
  b)      CLUSTER="eks-kwames-store-b";      REGION="eu-central-1" ;;
  delete) ;;
  *)      die "Usage: $0 [a|b|delete]" ;;
esac

command -v aws >/dev/null || die "aws CLI not found."
aws sts get-caller-identity >/dev/null 2>&1 || die "AWS credentials not found or expired."

ZONE_ID="$(aws route53 list-hosted-zones-by-name \
  --dns-name "${ZONE_NAME}" \
  --query "HostedZones[?Name=='${ZONE_NAME}.'].Id | [0]" \
  --output text 2>/dev/null | cut -d/ -f3)"
[[ -n "$ZONE_ID" && "$ZONE_ID" != "None" ]] || die "Could not find the ${ZONE_NAME} hosted zone."

change_batch() {
  local file
  file="$(mktemp)"
  cat >"$file"
  aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch "file://${file}" >/dev/null
  rm -f "$file"
}

if [[ "$TARGET" == "delete" ]]; then
  log "Removing ${DEMO_NAME}..."
  RECORD="$(aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
    --query "ResourceRecordSets[?Name=='${DEMO_NAME}.' && Type=='A'] | [0]" --output json)"
  if [[ "$RECORD" == "null" || -z "$RECORD" ]]; then
    log "No ${DEMO_NAME} A record found; nothing to delete."
    exit 0
  fi
  python3 - "$RECORD" <<'PY' | change_batch
import json,sys
r=json.loads(sys.argv[1])
print(json.dumps({"Changes":[{"Action":"DELETE","ResourceRecordSet":r}]}))
PY
  log "Deleted ${DEMO_NAME}."
  exit 0
fi

log "Looking up ${CLUSTER}'s ingress NLB (region ${REGION})..."
mapfile -t ARNS < <(aws resourcegroupstaggingapi get-resources \
  --region "$REGION" \
  --resource-type-filters elasticloadbalancing:loadbalancer \
  --tag-filters "Key=kubernetes.io/cluster/${CLUSTER},Values=owned" \
                "Key=kubernetes.io/service-name,Values=ingress-nginx/ingress-nginx-controller" \
  --query 'ResourceTagMappingList[].ResourceARN' --output text | tr '\t' '\n')
[[ ${#ARNS[@]} -eq 1 && -n "${ARNS[0]}" && "${ARNS[0]}" != "None" ]] || die "Expected exactly one ingress controller load balancer for ${CLUSTER}."
ARN="${ARNS[0]}"

LB_NAME="${ARN%/*}"; LB_NAME="${LB_NAME##*/}"
read -r LB_DNS LB_ZONE LB_SCHEME LB_STATE < <(aws elbv2 describe-load-balancers --region "$REGION" --names "$LB_NAME" \
  --query 'LoadBalancers[0].[DNSName,CanonicalHostedZoneId,Scheme,State.Code]' --output text)
[[ -n "$LB_DNS" && -n "$LB_ZONE" && "$LB_SCHEME" == "internet-facing" && "$LB_STATE" == "active" ]] \
  || die "Ingress load balancer must be active and internet-facing; DNS was not changed."

log "Pointing ${DEMO_NAME} -> ${LB_DNS} (${CLUSTER})..."
python3 - "$DEMO_NAME" "$LB_DNS" "$LB_ZONE" <<'PY' | change_batch
import json,sys
name,dns,zone=sys.argv[1:4]
print(json.dumps({"Changes":[{"Action":"UPSERT","ResourceRecordSet":{
  "Name": name+"." , "Type":"A",
  "AliasTarget":{"HostedZoneId":zone,"DNSName":dns,"EvaluateTargetHealth":True}}}]}))
PY

log "Done. ${DEMO_NAME} now points at ${CLUSTER}. DNS propagates in ~60s."
