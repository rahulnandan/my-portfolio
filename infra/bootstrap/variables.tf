variable "aws_region" {
  description = "Must match aws_region in ../terraform.tfvars - the policy's ARNs are region-scoped."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Must match project_name in ../terraform.tfvars - the policy's ARNs are scoped to <project_name>-*."
  type        = string
  default     = "rahuls-portfolio"
}

variable "iam_user_name" {
  description = "Name of the IAM user that runs the main Terraform stack."
  type        = string
  default     = "rahul_restricted"
}
