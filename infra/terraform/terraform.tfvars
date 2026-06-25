aws_region           = "eu-west-2"
aws_profile          = "ukddc-sandbox"
github_org           = "carrba"
github_repo          = "k8s-test-app"
github_ref           = "refs/heads/main"
ecr_repository_name  = "k8s-test-app"

# Keep true if this account does not already have the GitHub OIDC provider.
create_oidc_provider = false

# If create_oidc_provider = false, set this to your existing provider ARN.
existing_oidc_provider_arn = "arn:aws:iam::783050088916:oidc-provider/token.actions.githubusercontent.com"
