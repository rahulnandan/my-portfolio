output "alb_dns_name" {
  description = "The ALB's own hostname. Serves the app directly only when HTTPS is disabled; otherwise it redirects to app_url."
  value       = aws_lb.this.dns_name
}

output "app_url" {
  description = "Public URL of the deployed app."
  value       = local.https_enabled ? "https://${var.app_hostname}" : "http://${aws_lb.this.dns_name}"
}

output "aws_region" {
  value = var.aws_region
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  value = aws_ecs_service.this.name
}

output "ecs_task_family" {
  value = aws_ecs_task_definition.this.family
}

output "container_name" {
  value = var.project_name
}

output "ecs_execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.task.arn
}

output "github_actions_role_arn" {
  description = "Set this as the AWS_DEPLOY_ROLE_ARN repo variable in GitHub."
  value       = aws_iam_role.github_actions_deploy.arn
}
