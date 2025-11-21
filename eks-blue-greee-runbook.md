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
# Kubeconfig Update
aws eks update-kubeconfig --region ap-southeast-1 --name eks-cluster --alias eks-admin --profile eks-admin
aws eks update-kubeconfig --region ap-southeast-1 --name eks-cluster --alias junior-ops-engineer --profile junior-ops-engineer

```
## 3. Verify Cluster Access

```bash
# Check existing namespaces
kubectl get ns 

# Check system pods
kubectl get all -n kube-system
```
## 4. Deploying Bookinfo Services
Define the necessary Namespaces and RBAC for the microservices.
  
  ### I. Create Namespaces
  ```bash
kubectl create ns details
kubectl create ns reviews
kubectl create ns ratings
kubectl create ns productpage
  ```
  ### II. Apply RBAC and Deploy Blue Deployment Version
  ```bash
# Apply RBAC configurations
kubectl apply -f rbac.yaml

# Deploy Bookinfo Blue Version (Original) Microservices
kubectl apply -f blue-bookinfo.yaml

# Apply External Service (Kubernetes Service object)
kubectl apply -f external-svc.yaml -n productpage
  ```
## 5. AWS Load Balancer Controller Installation (ALB)
The LBC will automatically provision an AWS Application Load Balancer (ALB) based on Kubernetes Ingress Resources.

[Official Doc:](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/)

  ### I. Associate IAM OIDC Provider (Prerequisite for IRSA)
  ```bash
# Associate the OIDC provider with EKS for IAM Roles for Service Accounts (IRSA)
eksctl utils associate-iam-oidc-provider --cluster eks-cluster --approve --profile eks-admin
  ```
  ### II. Download Create IAM Policy
  Download the official IAM Policy and create it in AWS.
  ```bash
# Download the policy JSON file
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Create the policy in IAM 
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam-policy.json --profile eks-admin

  ```
  ### III. Create IAM Role + Service Account (IRSA)
  ```bash
# Create the IRSA using eksctl 
# Replace <account-id, aws profilename , region and clustername>.
eksctl create iamserviceaccount \
--cluster <cluster-name > \
--namespace kube-system \
--name aws-load-balancer-controller \
--attach-policy-arn arn:aws:iam::<account-id >:policy/AWSLoadBalancerControllerIAMPolicy \
--approve \
--region ap-southeast-1 \
--profile <your aws profile >
  ```
  ### IV. Install Controller Using Helm
  ```bash
# Add the Chart Repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the Controller
# Replace <vpc-id, clustername>.
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name > \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-southeast-1 \
  --set vpcId=<vpc-id >
  ```
 ### V. Verify Controller Deployment
 ```bash
# Check Deployment status
kubectl get deployment -n kube-system aws-load-balancer-controller

# Check Pod status
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
  ```
## 5. Apply Ingress Resource and Configure ALB Address in Route 53
### I. Apply Ingress Resource
```bash
# Apply the original Ingress for BLUE deployment (existing microservices)
kubectl apply -f orginal-ingress.yaml 

# Verify that AWS Load Balancer Controller created an ALB
kubectl get ingress bookinfo-ingress -n productpage -o wide
  ```
### II. Add ALB DNS to Route 53
```bash
- Go to Route 53 → Hosted Zones

- Select your domain (example: tunlab.xyz)

- Create a Record:

- Record name:
bookinfo.tunlab.xyz (or your preferred subdomain)

- Record type:
CNAME

- Value:
Paste the ALB DNS name from ADDRESS
Example:
k8s-prod-bookinfo-1234567890.elb.amazonaws.com

- TTL: 300 (default) # 60

- Routing policy: Simple

- Save record.

```
After DNS propagates (1–3 min), open: You should see the original BLUE productpage

http://bookinfo.tunlab.xyz

## 6. Traffic Switching (Blue/Green)
  ### I. Deploy Green Version
```bash
# Deploy the Green Version (New) Microservices
kubectl apply -f green-bookinfo.yaml
  ```
  ### II. Verify Service and Deployments 
  ```bash
# Deploy the Green Version (New) Microservices
kubectl get svc -n productpage 
kubectl get deplyoments -n deatils / rating / reviews
  ```
### III. Change Traffic Weight
```bash
# Reapply bookinfo-ingress.yaml after changing traffic weight
# (Example: Blue 0%, Green 100%)
kubectl apply -f green-ingress.yaml 

# Verify traffic shifting by accessing the ALB DNS name.


  ```
## 7. Monitoring (Datadog) Setup
Setup Datadog to gather Metrics, Logs, and Traces from the EKS Cluster.
### Create Datadog Account
```bash
   -  Install Add on datadog operator in EKS Console or install by helm 
   -  Create secret 
      # kubectl create secret generic datadog-secret --from-literal api-key=xxxxx -n   datadog-agent
   -  Enable customize your observability coverage
   -  Create the datadog-agent.yaml file and Copy the context into it
      # kubectl apply -f datadog-agent.yaml -n datadog-agent
```
- [Datadog Helm Chart Documentation](https://app.datadoghq.com/fleet/install-agent/latest?platform=kubernetes&_gl=1*xlxlw8*_gcl_au*MTUxMDgxNjk2NC4xNzYzMDQ0MTc4LjYyNTI3ODM0LjE3NjM0Mzc1MDIuMTc2MzQzNzUxMQ..*_ga*MTE4MDUzMjQ5Mi4xNzYzNDM3MDgx*_ga_KN80RDFSQK*czE3NjM0MzcwODEkbzEkZzEkdDE3NjM0MzgxMTkkajEzJGwwJGgxOTc4MDA1NjUx)