# Integration tests — apply + assert + destroy. Requires real AWS credentials.
# A REGIONAL Web ACL with no association is cheap + fast to create/destroy.

provider "aws" {
  region = "ap-south-1"
}

variables {
  namespace = "dvtca"
  stage     = "integ"
  name      = "waf"
  scope     = "REGIONAL"

  # No association so teardown is clean.
  association_resource_arns = []

  tags = { Environment = "integration-test", Ephemeral = "true" }
}

run "apply_and_assert" {
  command = apply

  assert {
    condition     = aws_wafv2_web_acl.this[0].arn != ""
    error_message = "Web ACL must be created."
  }
  assert {
    condition     = aws_wafv2_web_acl.this[0].capacity > 0
    error_message = "Web ACL should consume WCUs from the managed rules."
  }
}
