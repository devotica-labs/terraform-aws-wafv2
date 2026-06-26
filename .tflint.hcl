plugin "aws" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# The Web ACL name + description are derived from the label (namespace/stage/
# name). tflint statically evaluates them with the variable defaults (all
# null → empty string) and wrongly flags an "invalid" name/description, even
# though real usage always supplies a name. Disable these value checks; the
# AWS API enforces the real constraints at apply.
rule "aws_wafv2_web_acl_invalid_name" { enabled = false }
rule "aws_wafv2_web_acl_invalid_description" { enabled = false }

rule "terraform_deprecated_interpolation" { enabled = true }
rule "terraform_documented_outputs"       { enabled = true }
rule "terraform_documented_variables"     { enabled = true }
rule "terraform_naming_convention"        { enabled = true }
rule "terraform_required_providers"       { enabled = true }
rule "terraform_required_version"         { enabled = true }
rule "terraform_typed_variables"          { enabled = true }
rule "terraform_unused_declarations"      { enabled = true }
