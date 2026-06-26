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

  # Web ACL name composes to: dvtca-aps1-prod-payments
  namespace   = "dvtca"
  environment = "aps1"
  stage       = "prod"
  name        = "payments"

  scope = "REGIONAL"

  # Managed rule baseline, with one in count mode and a per-rule override.
  managed_rule_groups = [
    {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 10
      # Let large request bodies through (the API uploads documents).
      rule_action_overrides = {
        SizeRestrictions_BODY = "count"
      }
    },
    { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 20 },
    { name = "AWSManagedRulesSQLiRuleSet", priority = 30 },
    { name = "AWSManagedRulesAmazonIpReputationList", priority = 40 },
    # Observe-only while tuning.
    { name = "AWSManagedRulesLinuxRuleSet", priority = 50, count_only = true },
  ]

  # Tighter rate limit for the payments edge.
  rate_limit = {
    limit    = 1000
    priority = 100
  }

  # Always allow the office/VPN ranges; block a known-bad set.
  ip_allow_list = {
    addresses = ["203.0.113.0/24"]
    priority  = 1
  }
  ip_block_list = {
    addresses = ["198.51.100.7/32"]
    priority  = 2
  }

  # Block sanctioned jurisdictions.
  geo_block = {
    country_codes = ["KP", "IR", "SY", "CU"]
    priority      = 5
  }

  # Stream logs to a Firehose (name must start with aws-waf-logs-), redacting
  # the Authorization header.
  log_destination_configs = [
    "arn:aws:firehose:ap-south-1:111122223333:deliverystream/aws-waf-logs-payments",
  ]
  redacted_fields = [
    { single_header = ["authorization"] },
  ]

  # Attach to the public ALB.
  association_resource_arns = [
    "arn:aws:elasticloadbalancing:ap-south-1:111122223333:loadbalancer/app/dvtca-prod-payments/0123456789abcdef",
  ]

  tags = {
    Environment = "production"
    Project     = "payments"
    Owner       = "platform@devotica.com"
    CostCenter  = "PLATFORM"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-wafv2"
  }
}
