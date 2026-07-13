# Only the ALB is reachable from the internet. The ECS task's security
# group only accepts traffic from the ALB's security group - never
# 0.0.0.0/0 - even though the task also happens to have a public IP.
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow public HTTP to the ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from the internet (redirected to HTTPS when a domain is configured)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "To ECS tasks"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Allow traffic from the ALB only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "App port from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Egress-all is required here: the task pulls its image from Docker Hub
  # (public internet, no VPC endpoint) and ships logs to CloudWatch.
  egress {
    description = "Image pulls, CloudWatch Logs, etc."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-tasks-sg"
  }
}
