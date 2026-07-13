# Bootstrap stack — the IAM user Terraform itself runs as

## Why this is a separate stack

The main stack (`../`) runs as the IAM user defined *here*. If that user could
edit its own policy, it could grant itself `AdministratorAccess` in a single
`terraform apply` — so least-privilege would be a fiction. A principal that can
rewrite its own permissions effectively has every permission.

So this stack is applied by a **more privileged principal** (you, as admin) than
the one it constrains. That's the entire reason for the split, and it's why
permission changes can't be self-service from the main stack.

Read-only access to the policy *is* granted to the restricted user
(`IamPolicyReadOnlyForDriftDetection`), because reading your own permissions
carries no escalation risk and it lets `scripts/render-iam-policy.sh --diff`
detect drift.

## The policy body

`../bootstrap-iam-policy.json` is the single source of truth. It's consumed two
ways, so they can never diverge:

- **This Terraform** reads it via `templatefile()` — the `${AWS_ACCOUNT_ID}`,
  `${AWS_REGION}`, `${PROJECT_NAME}` placeholders are literally Terraform
  template syntax.
- **`scripts/render-iam-policy.sh`** substitutes the same placeholders for
  console paste.

## Applying it

**With admin CLI credentials** (preferred — policy changes become code):

```bash
cd infra/bootstrap
export AWS_PROFILE=<your-admin-profile>

# First time only: adopt the user/policy that already exist, so Terraform
# manages them instead of trying to recreate them.
terraform init
terraform import aws_iam_user.terraform rahul_restricted
terraform import aws_iam_policy.terraform \
  "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/rahuls-portfolio-terraform-bootstrap"

terraform plan
terraform apply
```

**Console-only** (no admin CLI credentials):

```bash
./scripts/render-iam-policy.sh          # paste into IAM -> Policies -> Edit -> JSON
./scripts/render-iam-policy.sh --diff   # check live IAM against the file in git
```

Either way the policy stays version-controlled in git; only the apply mechanism
differs.
