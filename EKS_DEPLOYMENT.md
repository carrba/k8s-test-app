# EKS Deployment Guide

## Prerequisites

1. **AWS CLI** - Installed and configured with credentials
2. **Docker** - For building and pushing images
3. **kubectl** - For Kubernetes commands
4. **EKS Cluster** - Already created in your AWS account
5. **IAM Permissions** - Access to ECR and EKS

## Step-by-Step Deployment

### Option 1: Automated Deployment (Recommended)

1. Update the variables in `deploy-to-eks.sh`:
   - `AWS_ACCOUNT_ID` - Your AWS Account ID
   - `AWS_REGION` - Your AWS region (e.g., us-east-1)
   - `CLUSTER_NAME` - Your EKS cluster name

2. Make the script executable and run:
```bash
chmod +x deploy-to-eks.sh
./deploy-to-eks.sh
```

### Option 2: Manual Deployment

#### 1. Authenticate with ECR
```bash
aws ecr get-login-password --region <YOUR_AWS_REGION> | docker login --username AWS --password-stdin <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.<YOUR_AWS_REGION>.amazonaws.com
```

#### 2. Create ECR Repository
```bash
aws ecr create-repository --repository-name k8s-test-app --region <YOUR_AWS_REGION>
```

#### 3. Build and Tag Docker Image
```bash
docker build -t k8s-test-app:latest .
docker tag k8s-test-app:latest <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/k8s-test-app:latest
```

#### 4. Push to ECR
```bash
docker push <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/k8s-test-app:latest
```

#### 5. Update kubeconfig
```bash
aws eks update-kubeconfig --name <YOUR_EKS_CLUSTER_NAME> --region <YOUR_AWS_REGION>
```

#### 6. Deploy to EKS
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

#### 7. Verify Deployment
```bash
kubectl get pods -n k8s-test-app
kubectl get svc -n k8s-test-app
```

## Kubernetes Manifests

- **namespace.yaml** - Creates isolated namespace for the app
- **deployment.yaml** - Defines 2 replicas with health checks and resource limits
- **service.yaml** - Exposes app via LoadBalancer (AWS ELB)

## Health Checks

The deployment includes:
- **Liveness Probe** - Restarts pod if `/health` fails
- **Readiness Probe** - Removes pod from load balancer if not ready

## Resource Limits

- **Requests**: 100m CPU, 128Mi Memory
- **Limits**: 500m CPU, 512Mi Memory

## Getting Service URL

```bash
kubectl get svc k8s-test-app -n k8s-test-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Then access your app at: `http://<EXTERNAL-IP>`

## Monitoring and Troubleshooting

### View deployment status
```bash
kubectl get deployment k8s-test-app -n k8s-test-app
```

### View pods
```bash
kubectl get pods -n k8s-test-app
```

### View logs
```bash
kubectl logs -n k8s-test-app deployment/k8s-test-app -f
```

### View events
```bash
kubectl get events -n k8s-test-app
```

### Describe deployment
```bash
kubectl describe deployment k8s-test-app -n k8s-test-app
```

## Updating the App

After making code changes:

1. Build and push new image:
```bash
docker build -t k8s-test-app:v1.1 .
docker tag k8s-test-app:v1.1 <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/k8s-test-app:v1.1
docker push <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/k8s-test-app:v1.1
```

2. Update deployment image:
```bash
kubectl set image deployment/k8s-test-app k8s-test-app=<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/k8s-test-app:v1.1 -n k8s-test-app
```

## Cleanup

To remove the deployment:
```bash
kubectl delete namespace k8s-test-app
```
