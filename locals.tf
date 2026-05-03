###############################################################
# locals.tf — Common tags applied to all resources
# Extracted from main.tf as recommended best practice
# Reference: https://developer.hashicorp.com/terraform/language/values/locals
###############################################################

locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Cluster     = var.cluster_name
    Owner       = "devops"
  }
}
