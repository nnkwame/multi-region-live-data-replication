# --- DNS: <project_name>.ironlabs.online -> this cluster's ingress NLB ---
#
# The NLB in front of the nginx ingress controller is created by Kubernetes
# (k8s/nginx-ingress/deploy.yaml, applied by up.sh) *after* this stack's first
# apply, so the Route53 record is gated behind `enable_domain_record`:
#   1. ./up.sh <name>                 -> cluster, no DNS record yet
#   2. deploy the app overlay         -> ingress controller NLB gets a hostname
#   3. ./dns.sh <name>                -> creates the record (sets the flag)
# up.sh re-detects an existing record in state and keeps the flag set on
# re-applies, so the record is not destroyed by a second `apply`.
#
# The kwamesdemostore.ironlabs.online demo URL is intentionally NOT managed
# here; see infra/aws_eks/demo_dns/cutover.sh.

variable "enable_domain_record" {
  description = "Create the <project_name>.<dns_zone_name> Route53 record. Only set true once the ingress controller NLB exists (dns.sh does this)."
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Public Route53 zone to register the app domain in."
  type        = string
  default     = "ironlabs.online"
}

variable "dns_ingress_service_tag" {
  description = "kubernetes.io/service-name tag of the NLB the in-tree controller creates for the ingress-nginx Service."
  type        = string
  default     = "ingress-nginx/ingress-nginx-controller"
}

data "aws_route53_zone" "app" {
  count        = var.enable_domain_record ? 1 : 0
  name         = var.dns_zone_name
  private_zone = false
}

data "aws_lb" "ingress" {
  count = var.enable_domain_record ? 1 : 0

  tags = {
    "kubernetes.io/service-name"                  = var.dns_ingress_service_tag
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

resource "aws_route53_record" "app" {
  count   = var.enable_domain_record ? 1 : 0
  zone_id = data.aws_route53_zone.app[0].zone_id
  name    = "${var.project_name}.${var.dns_zone_name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress[0].dns_name
    zone_id                = data.aws_lb.ingress[0].zone_id
    evaluate_target_health = true
  }
}
