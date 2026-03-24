# ============================================
# backend.tf - HCP Terraform (Terraform Cloud)
# Quan ly state file tap trung, bao mat bien so
# ============================================

terraform {
  cloud {
    organization = "htg-org-name"

    workspaces {
      name = "project-v11-production"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.38"
    }
  }

  required_version = ">= 1.6.0"
}
