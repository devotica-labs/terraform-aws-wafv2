# ---------------------------------------------------------------------------
# Web ACL scope + default action
# ---------------------------------------------------------------------------
variable "scope" {
  type        = string
  description = "REGIONAL (ALB / API Gateway / AppSync) or CLOUDFRONT. CLOUDFRONT web ACLs must be created in us-east-1."
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "default_action" {
  type        = string
  description = "What to do with a request that matches no rule: allow or block. The fintech default is allow — rules block known-bad traffic; switch to block only for an allow-list posture."
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action must be allow or block."
  }
}

variable "description" {
  type        = string
  description = "Description of the Web ACL. Defaults to the composed name."
  default     = null
}

# ---------------------------------------------------------------------------
# AWS managed rule groups (Devotica fintech baseline)
# ---------------------------------------------------------------------------
variable "managed_rule_groups" {
  type = list(object({
    name        = string
    vendor_name = optional(string, "AWS")
    priority    = number
    # Set true to run the group in count mode (observe only, no blocking).
    count_only = optional(bool, false)
    # Per-rule action overrides within the group (rule_name => "count"|"allow"|"block").
    rule_action_overrides = optional(map(string), {})
  }))
  description = "AWS (or marketplace) managed rule groups to attach. Defaults to a fintech baseline: Common, KnownBadInputs, SQLi, and the Amazon IP reputation list — all in block mode."
  # Devotica fintech default: a sensible managed-rules baseline, all blocking.
  default = [
    { name = "AWSManagedRulesCommonRuleSet", priority = 10 },
    { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 20 },
    { name = "AWSManagedRulesSQLiRuleSet", priority = 30 },
    { name = "AWSManagedRulesAmazonIpReputationList", priority = 40 },
  ]
}

# ---------------------------------------------------------------------------
# Rate limiting (Devotica fintech default: on)
# ---------------------------------------------------------------------------
variable "rate_limit" {
  type = object({
    limit              = optional(number, 2000)
    priority           = optional(number, 100)
    aggregate_key_type = optional(string, "IP")
    action             = optional(string, "block")
  })
  description = "Rate-based rule: blocks an IP exceeding `limit` requests in any 5-minute window. Set to null to disable."
  # Devotica fintech default: 2000 req / 5 min per IP, blocked.
  default  = {}
  nullable = true
}

# ---------------------------------------------------------------------------
# IP allow / block lists
# ---------------------------------------------------------------------------
variable "ip_allow_list" {
  type = object({
    addresses  = list(string)
    priority   = number
    ip_version = optional(string, "IPV4")
  })
  description = "Create an IP set and a rule that ALLOWs these CIDRs (evaluated before managed rules at the given priority)."
  default     = null
}

variable "ip_block_list" {
  type = object({
    addresses  = list(string)
    priority   = number
    ip_version = optional(string, "IPV4")
  })
  description = "Create an IP set and a rule that BLOCKs these CIDRs."
  default     = null
}

# ---------------------------------------------------------------------------
# Geo match
# ---------------------------------------------------------------------------
variable "geo_block" {
  type = object({
    country_codes = list(string)
    priority      = number
  })
  description = "Block requests from these ISO-3166 country codes (e.g. [\"KP\",\"IR\"])."
  default     = null
}

variable "geo_allow" {
  type = object({
    country_codes = list(string)
    priority      = number
  })
  description = "Allow only these countries — blocks everything else (default_action should stay allow; this rule blocks non-listed countries via a NOT match)."
  default     = null
}

# ---------------------------------------------------------------------------
# Association + logging + visibility
# ---------------------------------------------------------------------------
variable "association_resource_arns" {
  type        = list(string)
  description = "REGIONAL only: ARNs of resources (e.g. ALBs) to associate this Web ACL with. For CloudFront, set web_acl_id on the distribution instead."
  default     = []
}

variable "log_destination_configs" {
  type        = list(string)
  description = "Logging destination ARNs (CloudWatch log group / Kinesis Firehose / S3) — each name must start with `aws-waf-logs-`. Empty disables logging."
  default     = []
}

variable "redacted_fields" {
  type = list(object({
    method        = optional(bool, false)
    query_string  = optional(bool, false)
    uri_path      = optional(bool, false)
    single_header = optional(list(string))
  }))
  description = "Fields redacted from the logs (e.g. an Authorization header)."
  default     = []
}

variable "cloudwatch_metrics_enabled" {
  type        = bool
  description = "Emit CloudWatch metrics for the Web ACL and each rule."
  default     = true
}

variable "sampled_requests_enabled" {
  type        = bool
  description = "Store a sample of inspected requests for each rule (visible in the console)."
  default     = true
}
