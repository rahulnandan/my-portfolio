# Infrastructure bootstrap

This provisions the AWS side once: VPC, ALB, ECS Fargate cluster/service, and
the IAM OIDC role GitHub Actions uses to deploy. It is run manually, by you,
with your own AWS credentials — not by CI.

## IAM user for running Terraform

Don't use your root account or a personal admin user for this. Create a
dedicated IAM user scoped to exactly what this stack needs, using
[`bootstrap-iam-policy.json`](bootstrap-iam-policy.json):

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1   # match aws_region in terraform.tfvars

sed -e "s/\${AWS_ACCOUNT_ID}/${ACCOUNT_ID}/g" -e "s/\${AWS_REGION}/${REGION}/g" \
  bootstrap-iam-policy.json > /tmp/portfolio-terraform-policy.json

aws iam create-policy \
  --policy-name PortfolioTerraformBootstrap \
  --policy-document file:///tmp/portfolio-terraform-policy.json

aws iam create-user --user-name portfolio-terraform

aws iam attach-user-policy \
  --user-name portfolio-terraform \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/PortfolioTerraformBootstrap"

aws iam create-access-key --user-name portfolio-terraform
# save the AccessKeyId/SecretAccessKey it prints - shown only once
```

Configure a named profile with those keys (`aws configure --profile
portfolio-terraform`) and either `export AWS_PROFILE=portfolio-terraform` or
pass `-profile` via the `AWS_PROFILE` env var before running `terraform
apply` below. Most actions in the policy are scoped to `portfolio-*`
resource names; EC2 networking and ECS task-definition registration are
`Resource: "*"` only because those specific AWS APIs don't support
resource-level IAM conditions — not a scoping choice. This user has no
console password and no permissions outside this stack (no S3, no billing,
no other services), so a leaked access key's blast radius is limited to
these specific resources.

## One-time setup

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: your Docker Hub image, GitHub org/repo, region

terraform init
terraform plan
terraform apply
```

`container_image` only seeds the *initial* task definition — after that,
every push to `master` registers a new task definition revision and updates
the service directly via the CI/CD pipeline. The `aws_ecs_service` resource
has `lifecycle.ignore_changes = [task_definition]` specifically so that
re-running `terraform apply` later (e.g. to change the VPC or ALB) won't
revert the service to an older, Terraform-known revision and undo a CI
deploy.

## After `apply`, wire up GitHub

Copy these `terraform output` values into the GitHub repo's
**Settings → Secrets and variables → Actions**:

| Terraform output           | GitHub name              | Type     |
|-----------------------------|---------------------------|----------|
| `github_actions_role_arn`   | `AWS_DEPLOY_ROLE_ARN`     | Variable |
| `aws_region`                 | `AWS_REGION`               | Variable |
| `ecs_cluster_name`           | `ECS_CLUSTER`               | Variable |
| `ecs_service_name`           | `ECS_SERVICE`               | Variable |
| `ecs_task_family`            | `ECS_TASK_DEFINITION_FAMILY`| Variable |
| `container_name`             | `CONTAINER_NAME`            | Variable |

Plus two Docker Hub secrets (not from Terraform): `DOCKERHUB_USERNAME` and
`DOCKERHUB_TOKEN` (a Docker Hub access token, not your password).

Then browse to the `alb_dns_name` output — that's the public URL.

## Cost/security choices made here (and how to tighten them)

- **No NAT Gateway**: ECS tasks sit in public subnets with a public IP so
  they can reach Docker Hub, saving ~$32/month. Inbound is still locked to
  the ALB's security group only. Tighten by moving tasks to private subnets
  behind a NAT Gateway/instance.
- **No remote Terraform backend by default**: state is local
  (`terraform.tfstate`, gitignored). For team use, switch to an S3+DynamoDB
  backend (commented template in `providers.tf`).
- **No HTTPS listener**: no domain/ACM certificate is assumed. Add one and a
  443 listener in `alb.tf` if you have a domain.
- **OIDC, not static keys**: the GitHub Actions IAM role trust policy is
  scoped to `repo:<org>/<repo>:ref:refs/heads/master` — unusable from any
  other branch, fork, or repo, and there are no long-lived AWS credentials
  in GitHub at all.
- **Fargate 256/512 (smallest tier)** and a 14-day CloudWatch log retention
  keep both compute and log storage cost minimal for a demo workload.

## Tearing down

```bash
terraform destroy
```

Note this deletes the ECS service/cluster, ALB, VPC and the GitHub OIDC
IAM role. It does not touch the Docker Hub repository or GitHub Pages site.
