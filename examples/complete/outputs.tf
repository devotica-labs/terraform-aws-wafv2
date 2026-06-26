output "web_acl_arn" {
  description = "ARN of the Web ACL."
  value       = module.wafv2.web_acl_arn
}

output "web_acl_capacity" {
  description = "WCUs consumed by the rules."
  value       = module.wafv2.web_acl_capacity
}

output "ip_set_allow_arn" {
  description = "Allow-list IP set ARN."
  value       = module.wafv2.ip_set_allow_arn
}

output "logging_configuration_id" {
  description = "Logging configuration ID."
  value       = module.wafv2.logging_configuration_id
}
