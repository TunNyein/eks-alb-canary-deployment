# EKS Setup & Blue/Green Deployment Runbook

This Runbook provides a step-by-step guide from setting up an EKS Cluster with Terraform to configuring the AWS Load Balancer Controller (ALB), deploying Bookinfo microservices (Blue/Green), and setting up Datadog Monitoring.

## 1. EKS Cluster Creation (Terraform)

```bash
# Initialize Terraform in the current directory (first time run)
terraform init 

# Build the infrastructure in AWS
terraform apply --auto-approve
```

## 2. EKS Cluster Connectivity Management

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name eks-cluster --alias eks-admin --profile eks-admin

```
