# store_a: Kwame's store A. Region us-east-1, domain kwames-store-a.ironlabs.online.
project_name    = "kwames-store-a"
region          = "us-east-1"
eks_exclude_azs = ["use1-az3"]

# /16 VPC; subnets are carved from this in main.tf.
# Distinct per stack (store_b = 10.2.0.0/16, data_replication = 10.1.0.0/16)
# so the same-account VPCs could be peered later without CIDR collisions.
vpc_cidr_block = "10.0.0.0/16"

# Classroom account: the Kubernetes API endpoint is open. For anything
# production-like, replace with your own IP, e.g. ["203.0.113.10/32"].
endpoint_public_access_cidrs = ["0.0.0.0/0"]

instance_types = ["t4g.medium"]
