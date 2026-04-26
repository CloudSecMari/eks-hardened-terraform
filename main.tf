###############################################################
# main.tf — EKS Hardened Cluster + Private VPC
###############################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

###############################################################
# DATA SOURCES
###############################################################

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

###############################################################
# VPC
###############################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Private subnets — nodes and control plane ENIs live here
  private_subnets = var.private_subnet_cidrs

  # Public subnets — only for NAT Gateway and external load balancers
  public_subnets = var.public_subnet_cidrs

  # Single NAT Gateway (set to false in production for HA)
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for EKS subnet autodiscovery
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"          = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = local.common_tags
}

###############################################################
# EKS CLUSTER
###############################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # Place control plane ENIs in private subnets
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # HARDENING: API server private only — no public internet access
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # HARDENING: Encrypt Kubernetes secrets at rest with KMS
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # HARDENING: Enable all control plane log streams
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # Core cluster add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # Managed Node Group
  eks_managed_node_groups = {
    main = {
      name = "${var.cluster_name}-nodes"

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Nodes stay in private subnets — no public IPs
      subnet_ids = module.vpc.private_subnets

      # HARDENING: Encrypt root EBS volume at rest
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      # HARDENING: Enforce IMDSv2 — prevents SSRF credential theft
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
        instance_metadata_tags      = "disabled"
      }

      update_config = {
        max_unavailable_percentage = 33
      }

      tags = local.common_tags
    }
  }

  enable_cluster_creator_admin_permissions = true

  tags = local.common_tags
}

###############################################################
# KMS KEY — Secrets encryption with automatic rotation
###############################################################

resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster ${var.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-kms"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}"
  target_key_id = aws_kms_key.eks.key_id
}

###############################################################
# IRSA — Least-privilege role for EBS CSI Driver
###############################################################

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.common_tags
}

###############################################################
# SECURITY GROUP — Allow API server access from within VPC only
###############################################################

resource "aws_security_group_rule" "cluster_api_internal" {
  description       = "Allow API server access from within VPC"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = module.eks.cluster_security_group_id
}

###############################################################
# LOCALS
###############################################################

locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Cluster     = var.cluster_name
    Owner       = "devops"
  }
}
