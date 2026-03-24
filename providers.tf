# ============================================
# providers.tf - Cau hinh Providers
# ============================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "project-v11"
      Environment = "production"
      ManagedBy   = "terraform"
      Team        = var.team_name
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true
}
