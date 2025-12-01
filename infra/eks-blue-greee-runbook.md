# EKS Setup & Blue/Green Deployment Runbook

This runbook documents an operational, step-by-step procedure to provision EKS infrastructure, install required cluster controllers (ALB controller, ExternalDNS), deploy Bookinfo Blue/Green applications, and perform traffic shifting with Route 53.

Prerequisites
- AWS CLI, kubectl, eksctl, helm, terraform, jq installed and configured locally.
- AWS credentials with permissions to create IAM, EKS, and Route53 changes.
- Hosted zone for domain configured in Route 53 (e.g., `tunlab.xyz`).
- Terraform code in `infra/` ready to apply.

Quick checklist (high level)
- terraform apply (VPC, EKS clusters, IAM roles)
- kubeconfig update for both clusters
- install ALB Controller (IRSA) on both clusters
- install ExternalDNS on both clusters
- deploy blue & green manifests
- apply ingress and verify ALB + DNS
- perform weighted traffic shift and validate

#### 1) Provision infrastructure (Terraform)

```bash

# cd infra
terraform init 
terraform apply --auto-approve
```

#### 2) Update kubeconfig(s)

```bash
# for Blue
aws eks update-kubeconfig --region ap-southeast-1 --name eks-blue-cluster --alias eks-blue-cluster --profile eks-admin

# for Green
aws eks update-kubeconfig --region ap-southeast-1 --name eks-green-cluster --alias eks-green-cluster --profile eks-admin
```
Verify contexts:

```bash
kubectl config get-contexts
```
#### 3) Verify cluster access

```bash
# Check nodes and system pods
kubectl get nodes --context=eks-blue-cluster
kubectl get all -n kube-system --context=eks-blue-cluster

kubectl get nodes --context=eks-green-cluster
kubectl get all -n kube-system --context=eks-green-cluster
```
#### 4) Namespaces and RBAC

```bash
# Create namespaces used by Bookinfo (run for each cluster/context)

kubectl create ns details
kubectl create ns reviews
kubectl create ns ratings
kubectl create ns productpage

# Repeat for green
kubectl create ns details
kubectl create ns reviews
kubectl create ns ratings
kubectl create ns productpage

# Apply RBAC once per cluster
kubectl apply -f ../../manifests/rbac.yaml --context=eks-blue-cluster
kubectl apply -f ../../manifests/rbac.yaml --context=eks-green-cluster

```
#### 5) Deploy Blue and Green application manifests

```bash
# Deploy Blue version to Blue cluster
kubectl apply -f ../../manifests/blue-bookinfo/blue-bookinfo.yaml --context=eks-blue-cluster

# Deploy Green version to Green cluster
kubectl apply -f ../../manifests/green-bookinfo/green-bookinfo.yaml --context=eks-green-cluster

# Apply external service (if required)
kubectl apply -f ../../manifests/external-svc.yaml -n productpage --context=eks-blue-cluster
kubectl apply -f ../../manifests/external-svc.yaml -n productpage --context=eks-green-cluster
```

#### 6) Install AWS Load Balancer Controller (ALB) with IRSA (per cluster)
[Official Doc:](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/)

High level steps:
- Associate OIDC with cluster
- Create IAM policy for ALB Controller
- Create IAM service account (IRSA) and attach policy
- Install Helm chart with service account

Associate OIDC:

```bash
eksctl utils associate-iam-oidc-provider --cluster eks-blue-cluster --approve --profile eks-admin
eksctl utils associate-iam-oidc-provider --cluster eks-green-cluster --approve --profile eks-admin
```
Create ALB IAM policy (one-time):

```bash
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam-policy.json --profile eks-admin 
```
Create IAM service account (IRSA):

```bash
# Blue
eksctl create iamserviceaccount \
  --cluster eks-blue-cluster \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --profile eks-admin
# Green
eksctl create iamserviceaccount \
  --cluster eks-green-cluster \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --profile eks-admin
```
Install Helm chart (replace vpcId and clusterName):
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-blue-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-southeast-1 \
  --set vpcId=<VPC_ID> --profile eks-admin

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-green-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-southeast-1 \
  --set vpcId=<VPC_ID> --profile eks-admin
```

Verify:
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller --context=eks-blue-cluster
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --context=eks-blue-cluster
```

#### 7) Install ExternalDNS (per cluster)

Create minimal ExternalDNS policy (in manifests/external-dns-policy.json) and create IAM policy in AWS if not already created.

```bash
# Create ExternalDNS IAM policy (example in manifests/external-dns-policy.json)
aws iam create-policy --policy-name ExternalDNSPolicy --policy-document file://manifests/external-dns-policy.json --profile eks-admin || true


# Create IRSA for external-dns
eksctl create iamserviceaccount \
  --cluster eks-blue-cluster \
  --namespace kube-system \
  --name external-dns \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/ExternalDNSPolicy \
  --approve --profile eks-admin

eksctl create iamserviceaccount \
  --cluster eks-green-cluster \
  --namespace kube-system \
  --name external-dns \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/ExternalDNSPolicy \
  --approve --profile eks-admin
```


Install via Helm (adjust domainFilters & txtOwnerId):
```bash
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

helm upgrade --install external-dns external-dns/external-dns \
  -n kube-system \
  --set provider=aws \
  --set serviceAccount.create=false \
  --set serviceAccount.name=external-dns \
  --set txtOwnerId=eks-blue-cluster \
  --set domainFilters={tunlab.xyz} \
  --set policy=sync \
  --set aws.zoneType=public --profile eks-admin

# Repeat for green with txtOwnerId=eks-green-cluster
```

Verify:
```bash
kubectl get deployment -n kube-system external-dns --context=eks-blue-cluster
kubectl logs -n kube-system deployment/external-dns --context=eks-blue-cluster
```
#### 8) Apply Ingress & Configure DNS

```bash
# Apply Ingress (per cluster) - manifests in repo
kubectl apply -f ../../manifests/ingress/blue-ingress.yaml --context=eks-blue-cluster
kubectl apply -f ../../manifests/ingress/green-ingress.yaml --context=eks-green-cluster

# Confirm ALB was created by controller
kubectl get ingress -n productpage --context=eks-blue-cluster -o wide
kubectl get ingress -n productpage --context=eks-green-cluster -o wide

# ExternalDNS should create/annotate Route53 records for ALB endpoints automatically. Verify in Route53 console or:
aws route53 list-resource-record-sets --hosted-zone-id <HOSTED_ZONE_ID> --profile eks-admin | jq '.'
```

#### 9) Traffic shifting (weighted routing)

This repository uses ExternalDNS annotations for weighting traffic between blue/green. Example annotation format on the ingress resource:

```bash
# Set green weight to 50
kubectl -n productpage annotate ingress bookinfo-ingress \
  external-dns.alpha.kubernetes.io/aws-weight="50" --overwrite --context=eks-green-cluster

# Set blue weight to 50
kubectl -n productpage annotate ingress bookinfo-ingress \
  external-dns.alpha.kubernetes.io/aws-weight="50" --overwrite --context=eks-blue-cluster
```

Adjust weights to shift traffic gradually (e.g., 10 → 50 → 100). After annotation, ExternalDNS will update the Route53 record weights.

Validation checks
- Verify Pods/Deployments healthy: kubectl get pods -n productpage --context=eks-*-cluster
- Curl the application endpoint (domain) and validate responses for version headers or behavior.
- Confirm Route53 record-set weights and ALB targets in the AWS console.

Rollback
- To rollback to Blue=100: annotate blue weight 100 and green 0, or revert Terraform changes if infrastructure-level rollback needed.

```bash
kubectl -n productpage annotate ingress bookinfo-ingress \
  external-dns.alpha.kubernetes.io/aws-weight="100" --overwrite --context=eks-blue-cluster
kubectl -n productpage annotate ingress bookinfo-ingress \
  external-dns.alpha.kubernetes.io/aws-weight="0" --overwrite --context=eks-green-cluster
```

Troubleshooting (common problems)
- ALB not created:
  - Ensure ALB controller pods are running and there are no CRD errors in logs.
  - Check ingress annotations and service target types.
- ExternalDNS not creating records:
  - Confirm IRSA policy allows Route53 ChangeResourceRecordSets and hosted zone access.
  - Check ExternalDNS pod logs for errors.
- DNS not propagating:
  - Confirm Route53 record exists and ALB has healthy target groups.


# End of runbook
