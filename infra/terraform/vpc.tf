data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Two public subnets across two AZs: the minimum an ALB requires.
#
# Deliberate cost/security tradeoff: tasks run in these public subnets with a
# public IP (assign_public_ip = true on the ECS service) instead of private
# subnets behind a NAT Gateway. Docker Hub has no AWS VPC endpoint, so
# reaching it requires an internet route either way; a NAT Gateway would add
# ~$32/month + data processing charges for a single-service demo. The task's
# security group (see security_groups.tf) only allows inbound from the ALB,
# so having a public IP does not equate to open inbound access. For a
# stricter posture, move the ECS service to private subnets + a NAT Gateway
# (or NAT instance) and keep the ALB in the public subnets.
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
