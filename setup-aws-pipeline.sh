#!/bin/bash

set -e

# Configuration - must match deploy-to-eks.sh
AWS_PROFILE="ukddc-sandbox"
AWS_ACCOUNT_ID="783050088916"
AWS_REGION="eu-west-2"
ECR_REPO_NAME="k8s-test-app"
CODECOMMIT_REPO_NAME="k8s-test-app"
CODEBUILD_PROJECT_NAME="k8s-test-app-build"
CODEBUILD_ROLE_NAME="codebuild-k8s-test-app-role"

echo "🔧 Setting up AWS resources for k8s-test-app"
echo "=============================================="
echo ""

# Step 1: Create ECR repository
echo "📦 Creating ECR repository..."
aws ecr create-repository \
    --repository-name $ECR_REPO_NAME \
    --region $AWS_REGION \
    --profile $AWS_PROFILE 2>/dev/null || echo "   ECR repository already exists, skipping."

# Step 2: Create CodeCommit repository
echo "📁 Creating CodeCommit repository..."
aws codecommit create-repository \
    --repository-name $CODECOMMIT_REPO_NAME \
    --repository-description "k8s test app source code" \
    --region $AWS_REGION \
    --profile $AWS_PROFILE 2>/dev/null || echo "   CodeCommit repository already exists, skipping."

CODECOMMIT_URL=$(aws codecommit get-repository \
    --repository-name $CODECOMMIT_REPO_NAME \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --query "repositoryMetadata.cloneUrlHttp" \
    --output text)

echo "   CodeCommit URL: $CODECOMMIT_URL"

# Step 3: Create IAM role for CodeBuild
echo "👤 Creating IAM role for CodeBuild..."

TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

PERM_BOUNDARY="arn:aws:iam::$AWS_ACCOUNT_ID:policy/UKDDCAWSRestrictedAdmin-PermBoundary"

aws iam create-role \
    --role-name $CODEBUILD_ROLE_NAME \
    --assume-role-policy-document "$TRUST_POLICY" \
    --permissions-boundary "$PERM_BOUNDARY" \
    --profile $AWS_PROFILE 2>/dev/null || echo "   IAM role already exists, skipping."

# Attach policies to the CodeBuild role
echo "   Attaching policies to IAM role..."

# ECR access policy
ECR_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:'"$AWS_REGION"':'"$AWS_ACCOUNT_ID"':log-group:/aws/codebuild/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codecommit:GitPull"
      ],
      "Resource": "arn:aws:codecommit:'"$AWS_REGION"':'"$AWS_ACCOUNT_ID"':'"$CODECOMMIT_REPO_NAME"'"
    }
  ]
}'

aws iam put-role-policy \
    --role-name $CODEBUILD_ROLE_NAME \
    --policy-name "codebuild-k8s-test-app-policy" \
    --policy-document "$ECR_POLICY" \
    --profile $AWS_PROFILE

# Step 4: Create CodeBuild project
echo "🔨 Creating CodeBuild project..."

CODEBUILD_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/$CODEBUILD_ROLE_NAME"

aws codebuild create-project \
    --name $CODEBUILD_PROJECT_NAME \
    --description "Builds and pushes k8s-test-app Docker image to ECR" \
    --source "{
        \"type\": \"CODECOMMIT\",
        \"location\": \"$CODECOMMIT_URL\",
        \"buildspec\": \"buildspec.yml\"
    }" \
    --artifacts '{"type": "NO_ARTIFACTS"}' \
    --environment "{
        \"type\": \"LINUX_CONTAINER\",
        \"image\": \"aws/codebuild/standard:7.0\",
        \"computeType\": \"BUILD_GENERAL1_SMALL\",
        \"privilegedMode\": true,
        \"environmentVariables\": [
            {\"name\": \"AWS_ACCOUNT_ID\", \"value\": \"$AWS_ACCOUNT_ID\"},
            {\"name\": \"AWS_REGION\",     \"value\": \"$AWS_REGION\"},
            {\"name\": \"ECR_REPO_NAME\",  \"value\": \"$ECR_REPO_NAME\"}
        ]
    }" \
    --service-role "$CODEBUILD_ROLE_ARN" \
    --region $AWS_REGION \
    --profile $AWS_PROFILE 2>/dev/null || echo "   CodeBuild project already exists, skipping."

echo ""
echo "✅ Setup complete!"
echo ""
echo "📌 Next steps:"
echo "   1. Authenticate SSO for your profile:"
echo "      aws sso login --profile $AWS_PROFILE"
echo ""
echo "   2. Configure git to use your AWS profile for CodeCommit:"
echo "      git config credential.helper '!aws --profile $AWS_PROFILE codecommit credential-helper \$@'"
echo "      git config credential.UseHttpPath true"
echo ""
echo "   3. Push your code to CodeCommit:"
echo "      git remote add codecommit $CODECOMMIT_URL"
echo "      git push codecommit main"
echo ""
echo "   4. Run deploy-to-eks.sh to build and deploy:"
echo "      ./deploy-to-eks.sh"
