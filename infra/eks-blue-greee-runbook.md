# EKS Setup & Blue/Green Deployment Runbook

This runbook documents an operational, step-by-step procedure to provision EKS infrastructure, install required cluster controllers (ALB controller, ExternalDNS), deploy Bookinfo Blue/Green applications, and perform traffic shifting with Route 53.

## 1. EKS Cluster Creation (Terraform)

```bash
# Initialize Terraform in the current directory (first time run)
# cd infra
terraform init 

# Build the infrastructure in AWS
terraform apply --auto-approve
```

## 2. EKS Cluster Connectivity Management

```bash
# Kubeconfig Update
aws eks update-kubeconfig --region ap-southeast-1 --name eks-blue-cluster --alias eks-blue-cluster --profile eks-admin

aws eks update-kubeconfig --region ap-southeast-1 --name eks-green-cluster --alias eks-green-cluster --profile eks-admin


```
## 3. Verify Cluster Access

```bash
# Check existing namespaces
kubectl get ns 

# Check system pods
kubectl get all -n kube-system
```
## 4. Deploying Bookinfo Services
  
  ### I. Create Namespaces (per cluster)
  ```bash
kubectl create ns details
kubectl create ns reviews
kubectl create ns ratings
kubectl create ns productpage
  ```
  ### II. Apply RBAC and Deploy Blue Deployment Version
  ```bash
# Apply RBAC configurations (per cluster)
kubectl apply -f rbac.yaml  

# Deploy Bookinfo Blue Version (Original) Microservices (per cluster)
kubectl apply -f blue-bookinfo.yaml
kubectl apply -f green-bookinfo.yaml

# Apply External Service (Kubernetes Service object) (per cluster)
kubectl apply -f external-svc.yaml -n productpage
  ```
## 5. AWS Load Balancer Controller (ALB) Setup (per cluster)
The LBC will automatically provision an AWS Application Load Balancer (ALB) based on Kubernetes Ingress Resources.

[Official Doc:](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/)

  ### I. Associate IAM OIDC Provider (Prerequisite for IRSA)
  ```bash
# Associate the OIDC provider with EKS for IAM Roles for Service Accounts (IRSA)
eksctl utils associate-iam-oidc-provider --cluster eks-blue-cluster --approve --profile eks-admin
eksctl utils associate-iam-oidc-provider --cluster eks-green-cluster --approve --profile eks-admin

  ```
  ### II. Create IAM Policies
  Download the official IAM Policy and create it in AWS.
  ### ALB Controller Policy
  ```bash
# Download the policy JSON file
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Create the policy in IAM 
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam-policy.json --profile eks-admin


# ExternalDNS policy (minimal for Route53) - Create external-dns-policy.json
```bash
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}

```
then create # IAM Policy
```bash
  aws iam create-policy \
  --policy-name ExternalDNSPolicy \
  --policy-document file://external-dns-policy.json \
  --profile <your aws profile>
```

----

  ### III. Create IAM Role + Service Account (IRSA) for ALB and ExternaDNS in bouth cluster
  ```bash

# Replace <account-id, aws profilename , region and clustername>.
# For AWS Loadbalancer Controller
eksctl create iamserviceaccount \
--cluster <your eks blue cluster name> \
--namespace kube-system \
--name aws-load-balancer-controller \
--attach-policy-arn arn:aws:iam::<your aws account id>:policy/AWSLoadBalancerControllerIAMPolicy \
--approve \
--region ap-southeast-1 \
--profile <your aws profile>

###

eksctl create iamserviceaccount \
--cluster <your eks green cluster name> \
--namespace kube-system \
--name aws-load-balancer-controller \
--attach-policy-arn arn:aws:iam::<your aws account id>:policy/AWSLoadBalancerControllerIAMPolicy \
--approve \
--region ap-southeast-1 \
--profile <your aws profile>

# For ExternalDNS of Blue Cluster
eksctl create iamserviceaccount \
--cluster <your eks blue cluster name>  \
--namespace kube-system \
--name external-dns \
--attach-policy-arn arn:aws:iam::767397836388:policy/ExternalDNSPolicy \
--approve \
--region ap-southeast-1 \
--profile <your aws profile>

##### Green Cluster 
eksctl create iamserviceaccount \
--cluster <your eks green cluster name>  \
--namespace kube-system \
--name external-dns \
--attach-policy-arn arn:aws:iam::767397836388:policy/ExternalDNSPolicy \
--approve \
--region ap-southeast-1 \
--profile <your aws profile>
  ```
  ### IV. Install Controller Using Helm (per cluster)
  ```bash
# Add the Chart Repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the Controller for blue cluster
# Replace <vpc-id, clustername>.
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<your eks blue cluster name>  \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-southeast-1 \
  --set vpcId=<aws vpc id eks hosted>
  #### Install the Controller for green cluster
  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<your eks green cluster name \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-southeast-1 \
  --set vpcId=<aws vpc id eks hosted>
  ```
 ### V. Verify Controller Deployment
 ```bash
# Check Deployment status
kubectl get deployment -n kube-system aws-load-balancer-controller

# Check Pod status
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
  ```

## Install ExternalDNS via Helm (per cluster)
```bash
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update
  ```
# Install ExternalDNS using the service account external-dns created by eksctl:
```bash
helm upgrade --install external-dns external-dns/external-dns \
  -n kube-system \
  --set provider=aws \
  --set serviceAccount.create=false \
  --set serviceAccount.name=external-dns \
  --set txtOwnerId=eks-blue-cluster \
  --set domainFilters={tunlab.xyz} \
  --set policy=sync \
  --set aws.zoneType=public

  helm upgrade --install external-dns external-dns/external-dns \
  -n kube-system \
  --set provider=aws \
  --set serviceAccount.create=false \
  --set serviceAccount.name=external-dns \
  --set txtOwnerId=eks-gree-cluster \
  --set domainFilters={tunlab.xyz} \
  --set policy=sync \
  --set aws.zoneType=public

  ```

  # verify :
 kubectl get deployment -n kube-system external-dns
kubectl logs -n kube-system deployment/external-dns

## 5. Apply Ingress Resource and Configure ALB Address in Route 53
### I. Apply Ingress Resource
```bash
# Apply bookinfo blue/grenn ingress deployment (per cluster)    ### replace value with your ACM ARN
kubectl apply -f blue-bookinfo.yaml

# Verify that AWS Load Balancer Controller created an ALB
kubectl get ingress bookinfo-ingress -n productpage -o wide
  ```


# set green to 100 
kubectl -n productpage annotate ingress bookinfo-ingress \
  external-dns.alpha.kubernetes.io/aws-weight="50" --overwrite --context=eks-green-cluster
# set blue to 0
kubectl -n productpage annotate ingress bookinfo-ingress \
  external-dns.alpha.kubernetes.io/aws-weight="50" --overwrite --context=eks-blue-cluster


################ Done ########################