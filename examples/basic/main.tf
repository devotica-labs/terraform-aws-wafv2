# ---------------------------------------------------------------------------
# Provider block — CI-friendly skip flags + non-AWS-shaped placeholder creds.
# ---------------------------------------------------------------------------
provider "aws" {
  region                      = "ap-south-1"
  access_key                  = "not-a-real-aws-key"
  secret_key                  = "not-a-real-aws-secret"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# Uses local path during development.
# Change to Registry source after first release:
#   source  = "devotica-labs/wafv2/aws"
#   version = "~> 0.1"

module "wafv2" {
  source = "../.."

  # Web ACL name composes to: dvtca-sandbox-edge
  namespace = "dvtca"
  stage     = "sandbox"
  name      = "edge"

  scope = "REGIONAL"

  # Attach to a public ALB (terraform-aws-alb output).
  association_resource_arns = [
    "arn:aws:elasticloadbalancing:ap-south-1:111122223333:loadbalancer/app/dvtca-sandbox/0123456789abcdef",
  ]

  # Fintech defaults cover the rest: AWS managed rule baseline (Common,
  # KnownBadInputs, SQLi, IP reputation) in block mode, a 2000-req/5-min
  # rate limit, and CloudWatch metrics + sampled requests on.

  tags = {
    Environment = "sandbox"
    Project     = "terraform-aws-wafv2"
    Owner       = "platform@devotica.com"
    CostCenter  = "PLATFORM-OSS"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-wafv2"
  }
}
