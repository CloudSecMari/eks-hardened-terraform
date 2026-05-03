###############################################################
# variables.tf
###############################################################

variable "aws_region" {
  description = "AWS region to deploy the cluster"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile configured with aws configure"
  type        = string
  default     = "default"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-hardened"
}

variable "kubernetes_version" {
  description = "Kubernetes version — verify latest supported with: aws eks describe-addon-versions"
  type        = string
  default     = "1.35"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (nodes and control plane)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (NAT Gateway and external load balancers only)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group — t3.small is enough for sandbox"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}
