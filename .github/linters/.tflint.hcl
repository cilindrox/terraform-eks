plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"

  deep_check = false
}

plugin "terraform" {
  enabled = true
  version = "0.17.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"

  preset = "recommended"
}

##
# Configure linting rules below.
#
# github.com/terraform-linters/tflint-ruleset-terraform/blob/main/docs/rules
##

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format = "snake_case"
}

rule "terraform_standard_module_structure" {
  enabled = true
}
