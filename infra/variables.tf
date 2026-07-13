variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix/tag all resources."
  type        = string
  default     = "portfolio"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets (one per AZ, required by the ALB)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "container_port" {
  description = "Port the application listens on inside the container."
  type        = number
  default     = 8080
}

variable "container_image" {
  description = <<-EOT
    Docker Hub image (e.g. "yourdockerhubuser/portfolio:latest") used for the
    *initial* task definition only. Routine deploys register new task
    definition revisions directly from CI (see reusable-deploy-ecs.yml) and
    the service is configured with lifecycle.ignore_changes on
    task_definition so Terraform won't fight with CI-driven deploys.
  EOT
  type        = string
}

variable "desired_count" {
  description = "Number of Fargate tasks to run."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the ECS task, to bound log storage cost."
  type        = number
  default     = 14
}

variable "root_domain" {
  description = <<-EOT
    Public hosted zone already in Route 53 (e.g. "rahulnandan.dev"). Leave
    empty to skip HTTPS entirely and serve HTTP-only on the ALB's
    *.amazonaws.com name (no ACM cert is possible for that name).
  EOT
  type        = string
  default     = ""
}

variable "app_hostname" {
  description = "Fully qualified name to serve the app on, e.g. \"portfolio.rahulnandan.dev\". Required when root_domain is set."
  type        = string
  default     = ""
}

variable "github_org" {
  description = "GitHub org/user that owns the repository (used to scope the OIDC trust policy)."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (used to scope the OIDC trust policy)."
  type        = string
}

variable "create_oidc_provider" {
  description = <<-EOT
    Whether to create the GitHub Actions OIDC provider in this AWS account.
    Set to false if one already exists for token.actions.githubusercontent.com
    (an account can only have one per account) and set
    existing_oidc_provider_arn instead.
  EOT
  type        = bool
  default     = true
}

variable "existing_oidc_provider_arn" {
  description = "ARN of an existing GitHub OIDC provider, used only when create_oidc_provider is false."
  type        = string
  default     = ""
}
