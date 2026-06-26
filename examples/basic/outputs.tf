output "web_acl_arn" {
  description = "ARN of the Web ACL."
  value       = module.wafv2.web_acl_arn
}

output "web_acl_capacity" {
  description = "WCUs consumed."
  value       = module.wafv2.web_acl_capacity
}
