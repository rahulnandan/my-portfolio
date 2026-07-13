output "iam_user_name" {
  value = aws_iam_user.terraform.name
}

output "policy_arn" {
  value = aws_iam_policy.terraform.arn
}

# The fully-substituted policy document. Handy for diffing what Terraform would
# apply against what is actually live in IAM:
#   terraform output -raw policy_json > /tmp/want.json
output "policy_json" {
  description = "Rendered policy body, with account/region/project substituted."
  value       = local.policy_json
}
