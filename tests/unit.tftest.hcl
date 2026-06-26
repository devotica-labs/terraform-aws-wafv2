# Plan-only unit tests — no AWS credentials required. No data sources, so an
# empty mock provider suffices.

mock_provider "aws" {}

variables {
  namespace = "dvtca"
  stage     = "test"
  name      = "unit"
}

run "web_acl_created" {
  command = plan
  assert {
    condition     = length(aws_wafv2_web_acl.this) == 1
    error_message = "Exactly one Web ACL must be planned."
  }
}

run "default_action_allow_scope_regional" {
  command = plan
  assert {
    condition     = length(aws_wafv2_web_acl.this[0].default_action[0].allow) == 1
    error_message = "Default action must be allow by default."
  }
  assert {
    condition     = aws_wafv2_web_acl.this[0].scope == "REGIONAL"
    error_message = "Default scope must be REGIONAL."
  }
}

run "baseline_rules_present" {
  command = plan
  # 4 managed rule groups + the rate-limit rule (both on by default).
  assert {
    condition     = length(aws_wafv2_web_acl.this[0].rule) == 5
    error_message = "Default should plan 4 managed groups + 1 rate-limit rule."
  }
}

run "rate_limit_can_be_disabled" {
  command = plan
  variables {
    rate_limit = null
  }
  assert {
    condition     = length(aws_wafv2_web_acl.this[0].rule) == 4
    error_message = "Disabling rate_limit must drop to 4 rules (managed groups only)."
  }
}

run "no_ip_sets_by_default" {
  command = plan
  assert {
    condition     = length(aws_wafv2_ip_set.allow) == 0 && length(aws_wafv2_ip_set.block) == 0
    error_message = "No IP sets unless ip_allow_list / ip_block_list supplied."
  }
}

run "ip_sets_created_when_supplied" {
  command = plan
  variables {
    ip_allow_list = { addresses = ["203.0.113.0/24"], priority = 1 }
    ip_block_list = { addresses = ["198.51.100.7/32"], priority = 2 }
  }
  assert {
    condition     = length(aws_wafv2_ip_set.allow) == 1 && length(aws_wafv2_ip_set.block) == 1
    error_message = "An IP set must be created for each supplied list."
  }
  # Note: the Web ACL `rule` set length is unknown at plan here because the IP
  # rules reference the not-yet-created IP-set ARNs — assert on the IP sets.
}

run "no_association_or_logging_by_default" {
  command = plan
  assert {
    condition     = length(aws_wafv2_web_acl_association.this) == 0
    error_message = "No association without association_resource_arns."
  }
  assert {
    condition     = length(aws_wafv2_web_acl_logging_configuration.this) == 0
    error_message = "No logging config without log_destination_configs."
  }
}

run "association_and_logging_when_supplied" {
  command = plan
  variables {
    association_resource_arns = ["arn:aws:elasticloadbalancing:ap-south-1:111122223333:loadbalancer/app/x/0123456789abcdef"]
    log_destination_configs   = ["arn:aws:firehose:ap-south-1:111122223333:deliverystream/aws-waf-logs-x"]
  }
  assert {
    condition     = length(aws_wafv2_web_acl_association.this) == 1
    error_message = "Association must be created for each resource ARN."
  }
  assert {
    condition     = length(aws_wafv2_web_acl_logging_configuration.this) == 1
    error_message = "Logging config must be created when a destination is supplied."
  }
}
