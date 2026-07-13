# Infrastructure bootstrap

This provisions the AWS side once: VPC, ALB, ECS Fargate cluster/service, and
the IAM OIDC role GitHub Actions uses to deploy. It is run manually, by you,
with your own AWS credentials — not by CI.

## 1. Configure variables

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: your Docker Hub image, GitHub org/repo, region
```

## 2. Create a dedicated IAM user for running Terraform

Don't use your root account or a personal admin user for this. Create a
user scoped to exactly what this stack needs, using
[`bootstrap-iam-policy.json`](bootstrap-iam-policy.json) — its resource ARNs
are parameterized on your `project_name`/region, read straight out of the
`terraform.tfvars` you just created:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(grep aws_region terraform.tfvars | cut -d'"' -f2)
PROJECT_NAME=$(grep project_name terraform.tfvars | cut -d'"' -f2)
IAM_USER_NAME="${PROJECT_NAME}-terraform"

sed -e "s/\${AWS_ACCOUNT_ID}/${ACCOUNT_ID}/g" \
    -e "s/\${AWS_REGION}/${REGION}/g" \
    -e "s/\${PROJECT_NAME}/${PROJECT_NAME}/g" \
  bootstrap-iam-policy.json > /tmp/${PROJECT_NAME}-terraform-policy.json

aws iam create-policy \
  --policy-name "${PROJECT_NAME}-terraform-bootstrap" \
  --policy-document "file:///tmp/${PROJECT_NAME}-terraform-policy.json"

aws iam create-user --user-name "${IAM_USER_NAME}"

aws iam attach-user-policy \
  --user-name "${IAM_USER_NAME}" \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${PROJECT_NAME}-terraform-bootstrap"

aws iam create-access-key --user-name "${IAM_USER_NAME}"
# save the AccessKeyId/SecretAccessKey it prints - shown only once
```

Configure a named profile with those keys and use it for every command below:

```bash
aws configure --profile ${PROJECT_NAME}-terraform
export AWS_PROFILE=${PROJECT_NAME}-terraform
```

Most actions in the policy are scoped to `<project_name>-*` resource names;
EC2 networking and ECS task-definition registration are `Resource: "*"`
only because those specific AWS APIs don't support resource-level IAM
conditions — not a scoping choice. This user has no console password and no
permissions outside this stack (no S3, no billing, no other services), so a
leaked access key's blast radius is limited to these specific resources.

## 3. Provision

```bash
terraform init
terraform plan
terraform apply
```

`container_image` only seeds the *initial* task definition — after that,
every push to `main` registers a new task definition revision and updates
the service directly via the CI/CD pipeline. The `aws_ecs_service` resource
has `lifecycle.ignore_changes = [task_definition]` specifically so that
re-running `terraform apply` later (e.g. to change the VPC or ALB) won't
revert the service to an older, Terraform-known revision and undo a CI
deploy.

## 4. Wire up GitHub

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

Then browse to the `app_url` output — that's the public URL.

## HTTPS

Set `root_domain` and `app_hostname` in `terraform.tfvars` (see `dns.tf`) and
the stack requests an ACM certificate, DNS-validates it through your Route 53
hosted zone, adds a TLS 1.2+ listener on 443, and demotes port 80 to a 301
redirect. Leave them empty and the stack stays HTTP-only on the ALB hostname.

There is no way to serve HTTPS on the ALB's own `*.elb.amazonaws.com` name:
AWS owns that domain and ACM will not issue a certificate for a name you don't
control. HTTPS therefore requires a domain you own.

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
  scoped to `repo:<org>/<repo>:ref:refs/heads/main` — unusable from any
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
