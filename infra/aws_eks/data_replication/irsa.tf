# --- cert-manager IRSA: Route53 DNS-01 role ---
#
# cert-manager proves control of ironlabs.online to Let's Encrypt by creating
# _acme-challenge TXT records in the Route53 zone (DNS-01). It authenticates
# to Route53 through this role, assumed via the `cert-manager` ServiceAccount
# (EKS OIDC / IRSA) — no AWS credentials stored in the cluster. up.sh applies
# the SA annotation after installing cert-manager.
#
# least-privilege: DNS changes on this zone only (via zone ARN). Route53 is a
# global (us-east-1) service, so the eu-central-1 stack uses the same zone.
locals {
  dns_zone_name = "ironlabs.online"
}

data "aws_route53_zone" "ironlabs" {
  name         = local.dns_zone_name
  private_zone = false
}

module "cert_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.60"

  role_name = "cert-manager-${var.project_name}"

  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = [data.aws_route53_zone.ironlabs.arn]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider.arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }

  tags = {
    Project = var.project_name
  }
}