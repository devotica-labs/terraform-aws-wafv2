# Native label — a self-contained reimplementation of the common
# namespace/environment/stage/name/attributes labelling convention (no external
# null-label module). Composes `local.id` from the parts listed in
# `label_order`, cleaned, cased, and joined by `delimiter`, and a base tag set.

variable "enabled" {
  type        = bool
  description = "Set to false to make this module a no-op (create nothing)."
  default     = true
}

variable "namespace" {
  type        = string
  description = "Namespace / org prefix (e.g. \"dvtca\")."
  default     = null
}

variable "environment" {
  type        = string
  description = "Environment segment (e.g. a short region code)."
  default     = null
}

variable "stage" {
  type        = string
  description = "Stage / account segment (e.g. \"prod\")."
  default     = null
}

variable "name" {
  type        = string
  description = "Solution / base name (e.g. \"app\")."
  default     = null
}

variable "attributes" {
  type        = list(string)
  description = "Additional attributes appended to the id (e.g. [\"workers\"])."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Additional tags merged onto every taggable resource."
  default     = {}
}

variable "delimiter" {
  type        = string
  description = "Delimiter joining the id segments."
  default     = "-"
}

variable "label_order" {
  type        = list(string)
  description = "Order of the label segments used to build the id. Allowed keys: namespace, environment, stage, name, attributes."
  default     = ["namespace", "environment", "stage", "name", "attributes"]

  validation {
    condition     = length([for k in var.label_order : k if !contains(["namespace", "environment", "stage", "name", "attributes"], k)]) == 0
    error_message = "label_order keys must be a subset of: namespace, environment, stage, name, attributes."
  }
}

variable "label_value_case" {
  type        = string
  description = "Case applied to the composed id: lower, upper, or none."
  default     = "lower"

  validation {
    condition     = contains(["lower", "upper", "none"], var.label_value_case)
    error_message = "label_value_case must be one of: lower, upper, none."
  }
}

variable "regex_replace_chars" {
  type        = string
  description = "Regex (in /.../ form) of characters stripped from each id segment."
  default     = "/[^-a-zA-Z0-9]/"
}

variable "id_length_limit" {
  type        = number
  description = "Truncate the composed id to at most this many characters. 0 means no limit."
  default     = 0

  validation {
    condition     = var.id_length_limit == 0 || var.id_length_limit >= 6
    error_message = "id_length_limit must be 0 (no limit) or at least 6."
  }
}

locals {
  enabled = var.enabled

  label_values = {
    namespace   = var.namespace
    environment = var.environment
    stage       = var.stage
    name        = var.name
    attributes  = join(var.delimiter, var.attributes)
  }

  # Ordered, non-empty, regex-cleaned segments.
  id_segments = [
    for k in var.label_order : replace(lookup(local.label_values, k, ""), var.regex_replace_chars, "")
    if lookup(local.label_values, k, null) != null && lookup(local.label_values, k, "") != ""
  ]

  id_joined = join(var.delimiter, local.id_segments)
  id_cased  = var.label_value_case == "upper" ? upper(local.id_joined) : (var.label_value_case == "lower" ? lower(local.id_joined) : local.id_joined)
  id        = var.id_length_limit > 0 ? substr(local.id_cased, 0, var.id_length_limit) : local.id_cased

  # Generated identity tags, merged under the caller's tags (caller tags win).
  generated_tags = { for k, v in {
    Name        = local.id
    Namespace   = var.namespace
    Environment = var.environment
    Stage       = var.stage
  } : k => v if v != null && v != "" }

  tags = merge(local.generated_tags, var.tags)
}
