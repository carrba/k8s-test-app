# IAM resources for GitHub Actions OIDC were moved to github-actions-ecr-role.tf.
#
# Previous contents:
# data "aws_caller_identity" "current" {}
# data "aws_partition" "current" {}
# locals {
#   oidc_provider_arn = var.existing_oidc_provider_arn
#   repository_sub    = "repo:${var.github_org}/${var.github_repo}:ref:${var.github_ref}"
# }
# data "aws_iam_policy_document" "github_actions_assume_role" {
#   statement {
#     sid     = "GitHubActionsAssumeRole"
#     effect  = "Allow"
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     principals {
#       type        = "Federated"
#       identifiers = [local.oidc_provider_arn]
#     }
#     condition {
#       test     = "StringEquals"
#       variable = "token.actions.githubusercontent.com:aud"
#       values   = ["sts.amazonaws.com"]
#     }
#     condition {
#       test     = "StringEquals"
#       variable = "token.actions.githubusercontent.com:sub"
#       values   = [local.repository_sub]
#     }
#   }
# }
# resource "aws_iam_role" "github_actions_ecr_push" {
#   name                 = var.role_name
#   assume_role_policy    = data.aws_iam_policy_document.github_actions_assume_role.json
#   permissions_boundary  = "arn:aws:iam::783050088916:policy/UKDDCAWSRestrictedAdmin-PermBoundary"
# }
# data "aws_iam_policy_document" "ecr_push" {
#   statement {
#     sid    = "EcrGetAuthorizationToken"
#     effect = "Allow"
#     actions = ["ecr:GetAuthorizationToken"]
#     resources = ["*"]
#   }
#   statement {
#     sid    = "EcrPushPullSingleRepo"
#     effect = "Allow"
#     actions = [
#       "ecr:BatchCheckLayerAvailability",
#       "ecr:BatchGetImage",
#       "ecr:CompleteLayerUpload",
#       "ecr:DescribeImages",
#       "ecr:InitiateLayerUpload",
#       "ecr:PutImage",
#       "ecr:UploadLayerPart"
#     ]
#     resources = [
#       "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
#     ]
#   }
# }
# resource "aws_iam_policy" "ecr_push" {
#   name   = var.policy_name
#   policy = data.aws_iam_policy_document.ecr_push.json
# }
# resource "aws_iam_role_policy_attachment" "attach_ecr_push" {
#   role       = aws_iam_role.github_actions_ecr_push.name
#   policy_arn = aws_iam_policy.ecr_push.arn
# }
