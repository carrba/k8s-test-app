variable "aws_region" {
  description = "AWS region where IAM resources are managed."
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile used by the provider. Defaults to default when not set."
  type        = string
  default     = "default"
}

variable "role_name" {
  description = "IAM role name assumed by GitHub Actions via OIDC."
  type        = string
  default     = "github-actions-ecr-push-role"
}

variable "policy_name" {
  description = "Inline IAM policy name granting ECR push permissions."
  type        = string
  default     = "github-actions-ecr-push-policy"
}

variable "github_org" {
  description = "GitHub organization or username that owns the repo."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "github_ref" {
  description = "Git ref allowed to assume the role (for example, refs/heads/main)."
  type        = string
  default     = "refs/heads/main"

  validation {
    condition     = can(regex("^refs/", var.github_ref))
    error_message = "github_ref must start with refs/."
  }
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository GitHub Actions is allowed to push to."
  type        = string
}

variable "create_oidc_provider" {
  description = "Create GitHub OIDC provider if it does not already exist in the account."
  type        = bool
  default     = true
}

variable "existing_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN. Required when create_oidc_provider is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_oidc_provider || (var.existing_oidc_provider_arn != null && var.existing_oidc_provider_arn != "")
    error_message = "existing_oidc_provider_arn must be set when create_oidc_provider is false."
  }
}
