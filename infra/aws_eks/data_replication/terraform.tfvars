# data_replication: Strimzi Kafka + Connect + Prometheus/Grafana monitoring.
# Region us-east-1, domain kwames-data-replication.ironlabs.online (-> Grafana).
project_name    = "kwames-data-replication"
region          = "us-east-1"
eks_exclude_azs = ["use1-az3"]

# /16 VPC; subnets are carved from this in main.tf.
# Distinct per stack (store_a uses 10.0.x.x/16,
# store_b uses 10.1.x.x/16) so the same-account VPCs
# could be peered later without CIDR collisions.
vpc_cidr_block = "10.2.0.0/16"

# Classroom account: the Kubernetes API endpoint is open. For anything
# production-like, replace with your own IP, e.g. ["[IP_ADDRESS]/32"].
endpoint_public_access_cidrs = ["0.0.0.0/0"]

# m6a.xlarge (x86_64, sustained performance) on the ON_DEMAND group: the
# replication image is not tested on ARM, and burstable t3 would risk CPU-credit
# exhaustion under steady Kafka/Prometheus load. m6a is ~10% cheaper than m5
# and about t3.xlarge's price without the burst caveat.
instance_types = ["m6a.xlarge"]

# Kafka/Connect/Prometheus/Grafana are stateful workloads that all land on the
# ON_DEMAND group; nothing tolerates the spot taint here, so the spot group
# starts at zero (min_nodes=0 keeps the node_counts check satisfied).
min_nodes               = 0
desired_stateless_nodes = 0
