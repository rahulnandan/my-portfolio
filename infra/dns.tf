# HTTPS for the app.
#
# An ALB's own *.elb.amazonaws.com name can never have a TLS certificate - AWS
# owns that domain and ACM will not issue for a name you don't control - so
# HTTPS requires a domain you own. Everything here is gated on `root_domain`
# being set; leave it empty and the stack stays HTTP-only.

locals {
  https_enabled = var.root_domain != "" && var.app_hostname != ""
}

data "aws_route53_zone" "this" {
  count        = local.https_enabled ? 1 : 0
  name         = var.root_domain
  private_zone = false
}

resource "aws_acm_certificate" "this" {
  count             = local.https_enabled ? 1 : 0
  domain_name       = var.app_hostname
  validation_method = "DNS"

  # ACM cannot be replaced in place while a listener references it, so stand
  # the new cert up before tearing the old one down.
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = var.app_hostname
  }
}

# The CNAME record ACM looks for to prove we control the domain. Because the
# zone is in Route 53 in this same account, Terraform can write it directly and
# validation completes without any manual step.
resource "aws_route53_record" "cert_validation" {
  for_each = local.https_enabled ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id         = data.aws_route53_zone.this[0].zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# Blocks until ACM has actually seen the DNS record and issued the cert, so the
# 443 listener below is never created against a still-pending certificate.
resource "aws_acm_certificate_validation" "this" {
  count                   = local.https_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# Points the hostname at the ALB. An ALIAS (not CNAME) so it also works at a
# zone apex and costs nothing to resolve.
resource "aws_route53_record" "app" {
  count   = local.https_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = var.app_hostname
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
