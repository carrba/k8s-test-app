#!/bin/bash

set -e

# Configuration - Update these variables
AWS_PROFILE="ukddc-sandbox"
AWS_ACCOUNT_ID="783050088916"
AWS_REGION="eu-west-2"
ECR_REPO_NAME="k8s-test-app"
IMAGE_TAG="latest"
CLUSTER_NAME="carrb-eks-cluster"
CODECOMMIT_REPO_NAME="k8s-test-app"
CODEBUILD_PROJECT_NAME="k8s-test-app-build"

echo "🚀 Deploying k8s-test-app to EKS"
echo "=================================="

# Ensure profile-based auth is used for CodeCommit over HTTPS.
git config credential.helper "!aws --profile $AWS_PROFILE codecommit credential-helper \$@"
git config credential.UseHttpPath true

# Ensure SSO session is active for the selected profile.
if ! aws sts get-caller-identity --profile $AWS_PROFILE >/dev/null 2>&1; then
    echo "🔐 AWS SSO session not found for profile '$AWS_PROFILE'. Starting login..."
    aws sso login --profile $AWS_PROFILE
fi

# Step 1: Push source code to CodeCommit
echo "📤 Pushing source code to CodeCommit..."
CODECOMMIT_URL=$(aws codecommit get-repository \
    --repository-name $CODECOMMIT_REPO_NAME \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --query "repositoryMetadata.cloneUrlHttp" \
    --output text)

# Add CodeCommit remote if not already added
if ! git remote get-url codecommit &> /dev/null; then
    echo "   Adding CodeCommit remote..."
    git remote add codecommit $CODECOMMIT_URL
fi

git push codecommit HEAD:main

# Step 2: Create ECR repository if it doesn't exist
echo "🏗️  Creating ECR repository if needed..."
aws ecr create-repository \
    --repository-name $ECR_REPO_NAME \
    --region $AWS_REGION \
    --profile $AWS_PROFILE 2>/dev/null || echo "   ECR repository already exists, skipping."

# Step 3: Trigger CodeBuild
PROJECT_EXISTS=$(aws codebuild batch-get-projects \
    --names "$CODEBUILD_PROJECT_NAME" \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --query "length(projects)" \
    --output text)

if [ "$PROJECT_EXISTS" = "0" ]; then
    echo "⚠️  CodeBuild project '$CODEBUILD_PROJECT_NAME' not found."
    echo "   Running setup-aws-pipeline.sh to create required AWS resources..."
    bash ./setup-aws-pipeline.sh
fi

echo "🔨 Triggering CodeBuild to build and push Docker image..."
BUILD_ID=$(aws codebuild start-build \
    --project-name $CODEBUILD_PROJECT_NAME \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --query "build.id" \
    --output text)

echo "   Build started: $BUILD_ID"

# Step 4: Wait for CodeBuild to complete
echo "⏳ Waiting for CodeBuild to complete..."
while true; do
    BUILD_STATUS=$(aws codebuild batch-get-builds \
        --ids "$BUILD_ID" \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        --query "builds[0].buildStatus" \
        --output text)

    echo "   Build status: $BUILD_STATUS"

    if [ "$BUILD_STATUS" = "SUCCEEDED" ]; then
        echo "✅ Build succeeded!"
        break
    elif [ "$BUILD_STATUS" = "FAILED" ] || [ "$BUILD_STATUS" = "FAULT" ] || [ "$BUILD_STATUS" = "STOPPED" ] || [ "$BUILD_STATUS" = "TIMED_OUT" ]; then
        echo "❌ Build failed with status: $BUILD_STATUS"
        echo "   View logs: https://$AWS_REGION.console.aws.amazon.com/codesuite/codebuild/$AWS_ACCOUNT_ID/projects/$CODEBUILD_PROJECT_NAME/build/$BUILD_ID"
        exit 1
    fi

    sleep 15
done

# Step 5: Update kubeconfig
echo "🔗 Connecting to EKS cluster..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION --profile $AWS_PROFILE

# Step 6: Create namespace
echo "🔧 Creating namespace..."
kubectl apply -f k8s/namespace.yaml

# Step 7: Deploy to EKS
echo "🚀 Deploying to EKS..."
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Step 8: Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/k8s-test-app -n k8s-test-app --timeout=5m

# Step 9: Get LoadBalancer URL
echo ""
echo "✅ Deployment complete!"
echo ""
echo "🔍 Getting service details..."
kubectl get svc k8s-test-app -n k8s-test-app

echo ""
echo "📌 To view deployment status:"
echo "   kubectl get deployments -n k8s-test-app"
echo ""
echo "📌 To view pods:"
echo "   kubectl get pods -n k8s-test-app"
echo ""
echo "📌 To view logs:"
echo "   kubectl logs -n k8s-test-app deployment/k8s-test-app -f"
echo ""
echo "📌 To view service details:"
echo "   kubectl get svc k8s-test-app -n k8s-test-app"
