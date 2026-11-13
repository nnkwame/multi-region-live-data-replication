locals {
  cluster_name = "eks-${var.project_name}"

  # Two AZs is the minimum EKS accepts and keeps the subnet count (and cost) low.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

data "aws_availability_zones" "available" {
  # eg for us-east region, use1-az3 (us-east-1) doesn't support the EKS control plane.
  exclude_zone_ids = var.eks_exclude_azs

  # Skip Local Zones / Wavelength Zones, which EKS doesn't support.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

check "node_counts" {
  assert {
    condition     = var.min_nodes <= var.desired_stateless_nodes && var.desired_stateless_nodes <= var.max_stateless_nodes
    error_message = "Node counts must satisfy min_nodes <= desired_nodes <= max_nodes."
  }
}

check "stateful_node_counts" {
  assert {
    condition     = var.min_nodes <= var.desired_stateful_nodes && var.desired_stateful_nodes <= var.max_stateful_nodes
    error_message = "Node counts must satisfy min_nodes <= desired_nodes <= max_nodes."
  }
}

# --- Network ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = "vpc-${var.project_name}"
  cidr = var.vpc_cidr_block
  azs  = local.azs

  # /24 subnets: 10.0.1.0/24, 10.0.2.0/24 (private) and 10.0.11.0/24, 10.0.12.0/24 (public)
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr_block, 8, i + 1)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr_block, 8, i + 11)]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true

  # Let Kubernetes find the right subnets for public and internal load balancers.
  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
}

# --- EKS cluster + worker nodes ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  # OIDC provider for IRSA roles (cert-manager's Route53 DNS-01 role, irsa.tf).
  enable_irsa = true

  endpoint_public_access                   = true
  endpoint_public_access_cidrs             = var.endpoint_public_access_cidrs
  enable_cluster_creator_admin_permissions = true # whoever runs `terraform apply` gets kubectl admin

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # nodes live in private subnets, reachable only via the NAT

  # Module v21 doesn't let EKS install the default self-managed add-ons, so the
  # core networking ones must be listed here. `before_compute` creates them
  # before the node group, otherwise nodes never become Ready.
  addons = {
    vpc-cni                = { before_compute = true }
    eks-pod-identity-agent = { before_compute = true }
    kube-proxy             = {}
    coredns                = {}
    metrics-server         = {} # enables `kubectl top` and the HorizontalPodAutoscaler
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = module.ebs_csi_pod_identity.iam_role_arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  node_security_group_additional_rules = {
    ingress_nodes_all = {
      description = "Allow all node-to-node traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }
  eks_managed_node_groups = {
    default = {
      ami_type = "AL2023_ARM_64_STANDARD"
      # Diversified list: a single spot instance type can be unfulfillable
      # (UnfulfillableCapacity hit on t4g.medium in eu-central-1); several
      # types let the request be served from any available spot pool.
      instance_types = var.spot_instance_types
      # NOTE: the attribute is `capacity_type` — an unknown key like
      # `instance_availability_type` is silently ignored and the group
      # falls back to ON_DEMAND.
      capacity_type = "SPOT"

      min_size     = 0
      max_size     = var.max_stateless_nodes
      desired_size = var.desired_stateless_nodes

      # Shell access for debugging via SSM Session Manager (no EC2 key pair needed).
      iam_role_additional_policies = { ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }

      taints = {
        dedicated_spot = {
          key    = "dedicated"
          value  = "spot"
          effect = "NO_SCHEDULE" # Prevents untolerated pods from landing here
        }
      }

      labels = {
        "workload-type" = "stateless"
      }
    }

    stateful_ondemand = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = var.instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.min_nodes
      max_size     = var.max_stateful_nodes
      desired_size = var.desired_stateful_nodes

      # Shell access for debugging via SSM Session Manager (no EC2 key pair needed).
      iam_role_additional_policies = { ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }

      # Labels let Kubernetes know these are stable nodes (for db)
      labels = {
        "workload-type" = "stateful"
      }
    }
  }
}

# --- IAM role for the EBS CSI driver (EKS Pod Identity) ---
# The driver creates EBS volumes for PersistentVolumeClaims, so it needs its own
# IAM permissions; the node role alone isn't enough.
module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.10"

  name            = "ebs-csi-${var.project_name}"
  use_name_prefix = false

  # The default policy name ("AmazonEKS_EBS_CSI") is account-wide, so it collides
  # when several students share an account; make it unique per student.
  policy_name_prefix = "AmazonEKS_${var.project_name}_"

  attach_aws_ebs_csi_policy = true
}
