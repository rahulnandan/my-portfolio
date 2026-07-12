terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # State is local by default to keep the one-time bootstrap simple. For
  # anything beyond a personal demo, replace this with a remote backend
  # (S3 + DynamoDB lock table) before running `terraform apply` a second time:
  #
  # backend "s3" {
  #   bucket         = "<your-tfstate-bucket>"
  #   key            = "portfolio/terraform.tfstate"
  #   region         = "<your-region>"
  #   dynamodb_table = "<your-lock-table>"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}
