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

#### 6. Install or upgrade nginx ingress controller (NLB)
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
   --namespace ingress-nginx \
   --create-namespace \
   --set controller.ingressClassResource.name=nginx \
   --set controller.ingressClass=nginx \
   --set controller.service.type=LoadBalancer \
   --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=nlb \
   --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing
```

#### 7. Deploy to EKS
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/service-metrics.yaml
kubectl apply -f k8s/servicemonitor.yaml
```

#### 8. Verify Deployment
```bash
kubectl get pods -n k8s-test-app
kubectl get svc -n k8s-test-app
```

## Kubernetes Manifests

- **namespace.yaml** - Creates isolated namespace for the app
- **deployment.yaml** - Defines 2 replicas with health checks and resource limits
- **service.yaml** - Exposes app internally as a ClusterIP service
- **ingress.yaml** - Exposes app externally through the nginx ingress controller

## Health Checks

The deployment includes:
- **Liveness Probe** - Restarts pod if `/health` fails
- **Readiness Probe** - Removes pod from load balancer if not ready

## Resource Limits

- **Requests**: 100m CPU, 128Mi Memory
- **Limits**: 500m CPU, 512Mi Memory

## Getting Ingress URL

```bash
kubectl get ingress k8s-test-app -n k8s-test-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Then access your app at: `http://<NLB-HOSTNAME>`

Note: this ingress expects an nginx ingress controller installed with a LoadBalancer service. The command above configures that service as an AWS NLB.

## Monitoring and Troubleshooting

### Verify Prometheus resources
```bash
kubectl get servicemonitor -n k8s-test-app
kubectl get svc -n k8s-test-app -l app=k8s-test-app,metrics=enabled
```

### Verify metrics endpoint from cluster
```bash
kubectl port-forward -n k8s-test-app svc/k8s-test-app-metrics 5000:5000
curl -i http://localhost:5000/metrics
```

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
