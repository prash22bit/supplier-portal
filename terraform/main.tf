terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "SupplierQualityPortal"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix  = "sqp-${var.environment}"
  random_suffix = random_id.suffix.hex
}
