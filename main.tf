locals {
  # CloudWatch metric name for the Web ACL + rule prefix. WAF allows
  # [A-Za-z0-9-_] only; local.id is already lowercase alphanumeric + hyphens.
  metric_name = local.id

  create_ip_allow = local.enabled && var.ip_allow_list != null
  create_ip_block = local.enabled && var.ip_block_list != null

  # All rule priorities across every enabled rule — must be unique.
  rule_priorities = concat(
    [for g in var.managed_rule_groups : g.priority],
    var.rate_limit != null ? [var.rate_limit.priority] : [],
    var.ip_allow_list != null ? [var.ip_allow_list.priority] : [],
    var.ip_block_list != null ? [var.ip_block_list.priority] : [],
    var.geo_block != null ? [var.geo_block.priority] : [],
    var.geo_allow != null ? [var.geo_allow.priority] : [],
  )
}

check "unique_rule_priorities" {
  assert {
    condition     = length(local.rule_priorities) == length(distinct(local.rule_priorities))
    error_message = "WAF rule priorities must be unique across all rules (managed groups, rate limit, IP sets, geo)."
  }
}

# ---------------------------------------------------------------------------
# IP sets (allow / block)
# ---------------------------------------------------------------------------
resource "aws_wafv2_ip_set" "allow" {
  count = local.create_ip_allow ? 1 : 0

  name               = "${local.id}-allow"
  description        = "Allow-list IP set for ${local.id}"
  scope              = var.scope
  ip_address_version = var.ip_allow_list.ip_version
  addresses          = var.ip_allow_list.addresses
  tags               = local.tags
}

resource "aws_wafv2_ip_set" "block" {
  count = local.create_ip_block ? 1 : 0

  name               = "${local.id}-block"
  description        = "Block-list IP set for ${local.id}"
  scope              = var.scope
  ip_address_version = var.ip_block_list.ip_version
  addresses          = var.ip_block_list.addresses
  tags               = local.tags
}

# ---------------------------------------------------------------------------
# Web ACL
# ---------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "this" {
  count = local.enabled ? 1 : 0

  name        = local.id
  description = coalesce(var.description, "Web ACL for ${local.id}")
  scope       = var.scope

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  # ── IP allow list (evaluated first) ──────────────────────────────────────
  dynamic "rule" {
    for_each = var.ip_allow_list != null ? [var.ip_allow_list] : []
    content {
      name     = "ip-allow"
      priority = rule.value.priority
      action {
        allow {}
      }
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allow[0].arn
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${local.metric_name}-ip-allow"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ── IP block list ────────────────────────────────────────────────────────
  dynamic "rule" {
    for_each = var.ip_block_list != null ? [var.ip_block_list] : []
    content {
      name     = "ip-block"
      priority = rule.value.priority
      action {
        block {}
      }
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.block[0].arn
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${local.metric_name}-ip-block"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ── Geo block ────────────────────────────────────────────────────────────
  dynamic "rule" {
    for_each = var.geo_block != null ? [var.geo_block] : []
    content {
      name     = "geo-block"
      priority = rule.value.priority
      action {
        block {}
      }
      statement {
        geo_match_statement {
          country_codes = rule.value.country_codes
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${local.metric_name}-geo-block"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ── Geo allow (block everything NOT in the listed countries) ─────────────
  dynamic "rule" {
    for_each = var.geo_allow != null ? [var.geo_allow] : []
    content {
      name     = "geo-allow-only"
      priority = rule.value.priority
      action {
        block {}
      }
      statement {
        not_statement {
          statement {
            geo_match_statement {
              country_codes = rule.value.country_codes
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${local.metric_name}-geo-allow"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ── Rate limit ───────────────────────────────────────────────────────────
  dynamic "rule" {
    for_each = var.rate_limit != null ? [var.rate_limit] : []
    content {
      name     = "rate-limit"
      priority = rule.value.priority
      action {
        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }
      }
      statement {
        rate_based_statement {
          limit              = rule.value.limit
          aggregate_key_type = rule.value.aggregate_key_type
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${local.metric_name}-rate-limit"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ── AWS managed rule groups ──────────────────────────────────────────────
  dynamic "rule" {
    for_each = { for g in var.managed_rule_groups : g.name => g }
    content {
      name     = rule.value.name
      priority = rule.value.priority
      override_action {
        dynamic "none" {
          for_each = rule.value.count_only ? [] : [1]
          content {}
        }
        dynamic "count" {
          for_each = rule.value.count_only ? [1] : []
          content {}
        }
      }
      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = rule.value.vendor_name

          dynamic "rule_action_override" {
            for_each = rule.value.rule_action_overrides
            content {
              name = rule_action_override.key
              action_to_use {
                dynamic "allow" {
                  for_each = rule_action_override.value == "allow" ? [1] : []
                  content {}
                }
                dynamic "block" {
                  for_each = rule_action_override.value == "block" ? [1] : []
                  content {}
                }
                dynamic "count" {
                  for_each = rule_action_override.value == "count" ? [1] : []
                  content {}
                }
              }
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${local.metric_name}-${replace(rule.value.name, "/[^a-zA-Z0-9-_]/", "")}"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
    metric_name                = local.metric_name
    sampled_requests_enabled   = var.sampled_requests_enabled
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = local.enabled && length(var.log_destination_configs) > 0 ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this[0].arn
  log_destination_configs = var.log_destination_configs

  dynamic "redacted_fields" {
    for_each = var.redacted_fields
    content {
      dynamic "method" {
        for_each = redacted_fields.value.method ? [1] : []
        content {}
      }
      dynamic "query_string" {
        for_each = redacted_fields.value.query_string ? [1] : []
        content {}
      }
      dynamic "uri_path" {
        for_each = redacted_fields.value.uri_path ? [1] : []
        content {}
      }
      dynamic "single_header" {
        for_each = redacted_fields.value.single_header != null ? toset(redacted_fields.value.single_header) : []
        content {
          name = single_header.value
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Association (REGIONAL only — e.g. an ALB). CloudFront associates via the
# distribution's web_acl_id instead.
# ---------------------------------------------------------------------------
resource "aws_wafv2_web_acl_association" "this" {
  count = local.enabled && var.scope == "REGIONAL" ? length(var.association_resource_arns) : 0

  resource_arn = var.association_resource_arns[count.index]
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}
