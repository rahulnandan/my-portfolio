#!/usr/bin/env bash
# Render infra/bootstrap-iam-policy.json with your account/region/project
# substituted in, ready to paste into the AWS Console.
#
# Why paste rather than apply: the policy governs the very IAM user the main
# stack runs as, so that user deliberately cannot edit it (a principal that can
# rewrite its own permissions has all permissions). Applying it therefore needs
# admin credentials - either via the console, or by running the Terraform in
# infra/bootstrap/ with an admin profile.
#
# Usage:
#   ./scripts/render-iam-policy.sh              # prints to stdout
#   ./scripts/render-iam-policy.sh --diff       # diffs against the live policy
set -euo pipefail

cd "$(dirname "$0")/.."
TFVARS=infra/terraform.tfvars

if [[ ! -f "$TFVARS" ]]; then
  echo "error: $TFVARS not found - copy infra/terraform.tfvars.example first" >&2
  exit 1
fi

tfvar() { grep -E "^\s*$1\s*=" "$TFVARS" | head -1 | cut -d'"' -f2; }

REGION="$(tfvar aws_region)"
PROJECT_NAME="$(tfvar project_name)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

RENDERED="$(sed \
  -e "s/\${AWS_ACCOUNT_ID}/${ACCOUNT_ID}/g" \
  -e "s/\${AWS_REGION}/${REGION}/g" \
  -e "s/\${PROJECT_NAME}/${PROJECT_NAME}/g" \
  infra/bootstrap-iam-policy.json)"

if [[ "${1:-}" == "--diff" ]]; then
  POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${PROJECT_NAME}-terraform-bootstrap"
  VERSION="$(aws iam get-policy --policy-arn "$POLICY_ARN" \
    --query 'Policy.DefaultVersionId' --output text)"
  LIVE="$(aws iam get-policy-version --policy-arn "$POLICY_ARN" \
    --version-id "$VERSION" --query 'PolicyVersion.Document' --output json)"

  # Normalise both sides so ordering/whitespace noise doesn't show up as a diff.
  norm() { python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), indent=2, sort_keys=True))'; }
  if diff -u <(echo "$LIVE" | norm) <(echo "$RENDERED" | norm); then
    echo "live IAM policy matches infra/bootstrap-iam-policy.json"
  else
    echo
    echo "^ live IAM policy differs - paste the rendered version into the console" >&2
    exit 1
  fi
else
  echo "$RENDERED"
fi
