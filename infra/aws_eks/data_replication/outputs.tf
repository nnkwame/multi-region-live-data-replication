output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes API server."
  value       = module.eks.cluster_endpoint
}

output "kubernetes_version" {
  description = "Kubernetes version running on the control plane."
  value       = module.eks.cluster_version
}

output "region" {
  description = "AWS region the cluster runs in."
  value       = var.region
}

output "vpc_id" {
  description = "ID of the cluster VPC."
  value       = module.vpc.vpc_id
}

output "connect_command" {
  description = "Run this to point kubectl at the cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region} --alias ${module.eks.cluster_name}"
}

output "app_domain" {
  description = "Domain registered for this stack's app once dns.sh has run."
  value       = "${var.project_name}.${var.dns_zone_name}"
}

output "ingress_lb_dns_name" {
  description = "DNS name of the NLB in front of the nginx ingress controller. Empty until dns.sh sets enable_domain_record."
  value       = try(data.aws_lb.ingress[0].dns_name, "")
}

output "ingress_lb_zone_id" {
  description = "Route53 zone of the ingress NLB. Empty until dns.sh sets enable_domain_record."
  value       = try(data.aws_lb.ingress[0].zone_id, "")
}
output "cert_manager_irsa_role_arn" {
  description = "IRSA role cert-manager assumes for Route53 DNS-01 challenges. up.sh annotates the ServiceAccount with it."
  value       = module.cert_manager_irsa.iam_role_arn
}
