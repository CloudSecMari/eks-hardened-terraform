###############################################################
# terraform.tfvars — Override default values here
# Copy this file and adjust for your environment
# NOTE: This file is excluded from git via .gitignore
#       Use terraform.tfvars.example to document the structure
###############################################################

aws_region  = "us-east-1"
aws_profile = "default" # Change to your AWS CLI profile name

cluster_name       = "eks-hardened"
kubernetes_version = "1.35" # Verify latest: aws eks describe-addon-versions --query 'addons[0].addonVersions[0].compatibilities[].clusterVersion' --output text
environment        = "dev"

vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

node_instance_types = ["t3.small"] # Sufficient for sandbox; scale up for workloads
node_min_size       = 1
node_max_size       = 3
node_desired_size   = 2
