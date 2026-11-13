variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "project name (no spaces). Used to name some of the resources for the cluster."
  type        = string
}

variable "eks_exclude_azs" {
  description = "Availability Zone IDs that cannot host the EKS control plane. us-east-1 only: use1-az3 is a constrained AZ EKS rejects. eu-central-1 has no such AZ, so use [] there."
  type        = list(string)
  default     = ["use1-az3"]
}

variable "kubernetes_version" {
  description = "Kubernetes version. Keep it in EKS *standard* support; extended support costs 6x more. Check: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html"
  type        = string
  default     = "1.36"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr_block))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the Kubernetes API endpoint. Narrow this to your own IP (e.g. [\"203.0.113.7/32\"]) for anything beyond a classroom."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_types" {
  description = "EC2 instance types for the worker nodes."
  type        = list(string)
  default     = ["t4g.medium"]
}

variable "spot_instance_types" {
  description = "Instance types for the SPOT node group (all matching the ARM64 AMI). Several types let the spot request be fulfilled from any pool: a single type can be UnfulfillableCapacity (seen on t4g.medium in eu-central-1). All are sustained-eligible Graviton web-tier sizes."
  type        = list(string)
  default     = ["t4g.medium", "t4g.large", "m6g.medium", "m6g.large"]
}

# variable "instance_availability_type" {
#   # Obsolete: the correct node-group attribute is `capacity_type`
#   # (see main.tf). Kept as a note so nobody reintroduces the silent
#   # ON_DEMAND fallback by name.
# }

variable "desired_stateless_nodes" {
  description = "Number of worker nodes to start with. Must be between min_nodes and max_nodes."
  type        = number
  default     = 2
}

variable "desired_stateful_nodes" {
  description = "Number of worker nodes to start with. Must be between min_nodes and max_nodes."
  type        = number
  default     = 2
}

variable "min_nodes" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1

  validation {
    condition     = var.min_nodes >= 0
    error_message = "min_nodes cannot be negative."
  }
}

variable "max_stateless_nodes" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 4

  validation {
    condition     = var.max_stateless_nodes >= 1
    error_message = "max_nodes must be at least 1."
  }
}

variable "max_stateful_nodes" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 3

  validation {
    condition     = var.max_stateful_nodes >= 1
    error_message = "max_nodes must be at least 1."
  }
}

variable "http_port_voteapp" {
  description = "TCP port used for voteapp frontend."
  type        = number
  default     = 8080
}

variable "http_port_result" {
  description = "TCP port used for result frontend."
  type        = number
  default     = 8081
}

