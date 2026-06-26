# Contract tests — naming + the fintech baseline stay stable across versions.

mock_provider "aws" {}

variables {
  namespace = "dvtca"
  stage     = "test"
  name      = "contract"
}

run "web_acl_name_from_label" {
  command = plan
  assert {
    condition     = aws_wafv2_web_acl.this[0].name == "dvtca-test-contract"
    error_message = "Web ACL name must compose namespace-stage-name."
  }
}

run "metric_name_from_label" {
  command = plan
  assert {
    condition     = aws_wafv2_web_acl.this[0].visibility_config[0].metric_name == "dvtca-test-contract"
    error_message = "Web ACL metric name must equal the composed id."
  }
}

run "visibility_metrics_on_by_default" {
  command = plan
  assert {
    condition     = aws_wafv2_web_acl.this[0].visibility_config[0].cloudwatch_metrics_enabled == true
    error_message = "CloudWatch metrics must be on by default."
  }
  assert {
    condition     = aws_wafv2_web_acl.this[0].visibility_config[0].sampled_requests_enabled == true
    error_message = "Sampled requests must be on by default."
  }
}

run "default_rate_limit_2000" {
  command = plan
  assert {
    condition     = anytrue([for r in aws_wafv2_web_acl.this[0].rule : tostring(r.statement[0].rate_based_statement[0].limit) == "2000" if length(r.statement[0].rate_based_statement) > 0])
    error_message = "Default rate limit must be 2000."
  }
}
