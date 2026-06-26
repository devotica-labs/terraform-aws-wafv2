output "web_acl_id" {
  description = "The ID of the WAFv2 Web ACL."
  value       = one(aws_wafv2_web_acl.this[*].id)
}

output "web_acl_arn" {
  description = "The ARN of the WAFv2 Web ACL. For CloudFront, set this as the distribution's web_acl_id."
  value       = one(aws_wafv2_web_acl.this[*].arn)
}

output "web_acl_name" {
  description = "The name of the Web ACL."
  value       = one(aws_wafv2_web_acl.this[*].name)
}

output "web_acl_capacity" {
  description = "Web ACL capacity units (WCUs) consumed by the rules."
  value       = one(aws_wafv2_web_acl.this[*].capacity)
}

output "ip_set_allow_arn" {
  description = "ARN of the allow-list IP set (null if none)."
  value       = one(aws_wafv2_ip_set.allow[*].arn)
}

output "ip_set_block_arn" {
  description = "ARN of the block-list IP set (null if none)."
  value       = one(aws_wafv2_ip_set.block[*].arn)
}

output "logging_configuration_id" {
  description = "ID of the Web ACL logging configuration (null if logging disabled)."
  value       = one(aws_wafv2_web_acl_logging_configuration.this[*].id)
}
