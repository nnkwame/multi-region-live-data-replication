# store_b: Kwame's store B. Region eu-central-1 (Frankfurt), domain kwames-store-b.ironlabs.online.
project_name = "kwames-store-b"
region       = "eu-central-1"

# Frankfurt has no EKS-excluded AZ (all 3 AZs support the control plane),
# so no exclusion is needed there.
eks_exclude_azs = []

# /16 VPC; subnets are carved from this in main.tf.
# Distinct per stack (store_a uses 10.0.x.x/16,
# data_replication uses 10.2.x.x/16) so the same-account
# VPCs could be peered later without CIDR collisions.
vpc_cidr_block = "10.1.0.0/16"

# Classroom account: the Kubernetes API endpoint is open. For anything
# production-like, replace with your own IP, e.g. ["[IP_ADDRESS]/32"].
endpoint_public_access_cidrs = ["0.0.0.0/0"]

instance_types = ["t4g.medium"]
