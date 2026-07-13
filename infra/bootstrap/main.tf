# Bootstrap stack: the IAM user that the *main* stack (../) runs as, and the
# policy that constrains it.
#
# This is a SEPARATE stack, applied with ADMIN credentials, on purpose. The
# main stack runs as this user - so if that user could edit this policy, it
# could grant itself AdministratorAccess in a single apply and least-privilege
# would be meaningless. Keeping the policy out of the stack it governs is the
# whole point of the split.
#
# The policy body is ../bootstrap-iam-policy.json, shared verbatim with the
# console-paste workflow (see scripts/render-iam-policy.sh) so there is exactly
# one source of truth for these permissions.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  policy_json = templatefile("${path.module}/../bootstrap-iam-policy.json", {
    AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
    AWS_REGION     = var.aws_region
    PROJECT_NAME   = var.project_name
  })
}

resource "aws_iam_user" "terraform" {
  name = var.iam_user_name

  tags = {
    Name    = var.iam_user_name
    Purpose = "Runs the ${var.project_name} Terraform stack"
  }
}

resource "aws_iam_policy" "terraform" {
  name        = "${var.project_name}-terraform-bootstrap"
  description = "Least-privilege permissions for provisioning the ${var.project_name} stack"
  policy      = local.policy_json
}

resource "aws_iam_user_policy_attachment" "terraform" {
  user       = aws_iam_user.terraform.name
  policy_arn = aws_iam_policy.terraform.arn
}
