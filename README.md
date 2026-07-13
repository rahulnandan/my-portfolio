# my-portfolio

A small Spring Boot portfolio site, containerized and deployed to AWS ECS
Fargate via a modular GitHub Actions CI/CD pipeline.

## Architecture

```
push (feature branch)                 push to main
        │                                    │
        ▼                                    ▼
  ci-feature-branch.yml               cd-main.yml
        │                                    │
        ├─ build-test  ───────────────────── build-test
        ├─ static-analysis (needs build-test)  ├─ static-analysis
        ├─ publish-pages  (needs static-analysis) ├─ publish-pages
        └─ docker-build-push (needs build-test)  ├─ docker-build-push (:latest too)
                                              └─ deploy-ecs (needs docker-build-push)
```

Both workflows are thin orchestrators over five reusable workflows in
`.github/workflows/reusable-*.yml`, each independently callable/testable:

| Reusable workflow | Does |
|---|---|
| `reusable-build-test.yml` | `mvn -B verify` (compile + unit tests), uploads the jar |
| `reusable-static-analysis.yml` | `mvn -B site` → SpotBugs + PMD HTML reports |
| `reusable-publish-pages.yml` | Publishes the report site to GitHub Pages (per-branch path) |
| `reusable-docker-build-push.yml` | Builds and pushes the image to Docker Hub |
| `reusable-deploy-ecs.yml` | Registers a new ECS task definition revision and deploys it |

AWS deployment only happens on `main` — redeploying a shared public ECS
service on every feature-branch push isn't a real environment strategy.
Feature branches still get full build/test/analysis/Pages/Docker coverage.

Infrastructure (VPC, ALB, ECS Fargate, IAM/OIDC) is Terraform in `infra/` —
see [infra/README.md](infra/README.md) for the one-time bootstrap. CI never
runs `terraform apply`; it only updates the ECS service's task definition
(see the `ignore_changes` note there).

## One-time setup

1. Create the Docker Hub repository `<you>/portfolio` (or let the first push
   create it) and generate a Docker Hub **access token**.
2. `cd infra && terraform init && terraform apply` (see that directory's
   README for the IAM bootstrap user, variables, and cost/security notes).
3. In GitHub **Settings → Secrets and variables → Actions**, add:
   - Secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`
   - Variables (from `terraform output`): `AWS_DEPLOY_ROLE_ARN`,
     `AWS_REGION`, `ECS_CLUSTER`, `ECS_SERVICE`,
     `ECS_TASK_DEFINITION_FAMILY`, `CONTAINER_NAME`
4. Push a feature branch → CI runs. Merge/push to `main` → CD builds,
   pushes, and deploys.
5. Open `terraform output app_url` in a browser on your laptop — that's the
   public URL, fronted by the ALB. Currently
   **https://portfolio.rahulnandan.dev**.

## Running locally

```bash
mvn spring-boot:run          # http://localhost:8080
# or
docker build -t portfolio .
docker run -p 8080:8080 portfolio
```

## AWS design choices (summary — details in infra/README.md)

- **ECS Fargate**, 256 CPU / 512 MB — cheapest Fargate tier, no servers to patch.
- **No NAT Gateway** — public subnets + public IP on the task instead, saving
  ~$32/month; inbound still locked to the ALB's security group only.
- **OIDC federation** for GitHub Actions → AWS, scoped to
  `repo:<org>/<repo>:ref:refs/heads/main` — no long-lived AWS keys anywhere.
- **HTTPS** via an ACM certificate (DNS-validated in Route 53), TLS 1.2+ only,
  with port 80 permanently redirecting rather than serving. Note an ALB can
  never have a certificate for its own `*.amazonaws.com` name — AWS owns that
  domain — so TLS requires a domain you control.
- **Deployment circuit breaker + rollback** on the ECS service.
- **14-day CloudWatch log retention** to bound log storage cost.
- **Least-privilege IAM**, with the policy that governs Terraform's own user
  kept in a separate stack (`infra/bootstrap/`) applied by an admin principal —
  a user that can rewrite its own policy can grant itself admin.
