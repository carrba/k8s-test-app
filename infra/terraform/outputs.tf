output "github_actions_role_arn" {
  description = "IAM role ARN to store in GitHub secret AWS_GITHUB_ACTIONS_ROLE_ARN."
  value       = aws_iam_role.github_actions_ecr_push.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN used by the role trust policy."
  value       = local.oidc_provider_arn
}
