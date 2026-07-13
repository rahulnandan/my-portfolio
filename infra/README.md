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

## 2. AWS credentials

Configure a profile for an IAM user that can create the resources below (VPC,
ALB, ECS, ACM, Route 53 records, and the IAM roles in `oidc.tf`):

```bash
aws configure --profile <your-profile>
export AWS_PROFILE=<your-profile>
```

> **Note on posture.** This project currently uses an IAM user with
> `AdministratorAccess` for local Terraform runs. That is convenient but broad:
> the access key is long-lived, so if it leaks the blast radius is the whole
> account rather than this stack. A least-privilege alternative is to scope the
> user to just the actions this stack needs and apply that policy from a
> separate admin-run stack (a user that can edit its own policy can always
> escalate to admin, so the policy cannot live in the stack it governs).
>
> Note this applies only to *local* Terraform runs. The **deploy path is not
> affected**: GitHub Actions authenticates via OIDC federation with no
> long-lived keys at all, assuming a role scoped to `ecs:UpdateService` on this
> one service, and only from `refs/heads/main` (see `oidc.tf`).

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

Plus two Docker Hub values (not from Terraform):

| GitHub name          | Type     | Value                                        |
|-----------------------|----------|----------------------------------------------|
| `DOCKERHUB_USERNAME`  | Variable | your Docker Hub account name                  |
| `DOCKERHUB_TOKEN`     | Secret   | a Docker Hub access token, not your password  |

`DOCKERHUB_USERNAME` must be a **variable**, not a secret. The image reference
is emitted as a workflow output, and GitHub scrubs any output whose value
contains a secret — as a secret it silently arrived empty at the deploy job.

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
