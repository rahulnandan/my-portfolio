# Bootstrap stack — the IAM user Terraform itself runs as

## Why this is a separate stack

The main stack (`../`) runs as the IAM user defined *here*. If that user could
edit its own policy, it could grant itself `AdministratorAccess` in a single
`terraform apply` — so least-privilege would be a fiction. A principal that can
rewrite its own permissions effectively has every permission.

So this stack is applied by a **more privileged principal** (an admin) than the
one it constrains. That is the entire reason for the split, and it's why
permission changes cannot be self-service from the main stack.

The restricted user *is* granted read-only access to its own policy
(`IamPolicyReadOnlyForDriftDetection`) — reading your own permissions carries no
escalation risk, and it lets `terraform plan` here detect drift.

## The policy

`iam-policy.json` is the source of truth, consumed via `templatefile()` — its
`${AWS_ACCOUNT_ID}` / `${AWS_REGION}` / `${PROJECT_NAME}` placeholders are
Terraform template syntax, substituted from the variables in `variables.tf`
(keep those in sync with `../terraform.tfvars`).

## Applying

Requires **admin credentials** — not the `rahul_restricted` user the main stack
uses.

```bash
cd infra/bootstrap
export AWS_PROFILE=<your-admin-profile>

terraform init

# First time only: adopt the user and policy that already exist in AWS, so
# Terraform manages them rather than trying to create duplicates.
terraform import aws_iam_user.terraform rahul_restricted
terraform import aws_iam_policy.terraform \
  "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/rahuls-portfolio-terraform-bootstrap"

terraform plan    # also serves as the drift check
terraform apply
```

After the import, every future permission change is an edit to
`iam-policy.json` followed by `terraform apply` here. No console, no
copy-paste.
