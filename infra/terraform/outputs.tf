output "alb_dns_name" {
  description = "Public URL of the deployed app (http://<this>)."
  value       = aws_lb.this.dns_name
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
