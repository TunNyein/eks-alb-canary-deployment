# Deploy Datadog, Configure EKS RBAC, Deploy Bookinfo Microservices & Install AWS Load Balancer Controller

## Deploy EKS Cluster 

- terraform init 
- terraform apply --auto-approve

## After EKS Cluster Create Complete
- update kubeconfig for eks admin

  # aws eks update-kubeconfig --region ap-southeast-1 --name eks-cluster --alias eks-admin --profile eks-admin

- verify cluster access
  # kubectl get ns 
  # kubectl get all -n kube-system

## Create namespaces
kubectl create ns details
kubectl create ns reviews
kubectl create ns ratings
kubectl create ns productpage

## Apply RBAy.aml
kubectl apply -f rbac.yaml

## Deploy Blue Microservices (Bookinfo)
kubectl apply -f blue-bookinfo.yaml

## Apply External Service (Under productpage namespace)
kubectl apply -f external-svc.yaml -n productpage

## Apply Ingress (ALB Routing)
kubectl apply -f bookinfo-ingress.yaml -n productpage

## Install AWS Load Balancer Controller
Official docs:
https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/

1. Create an IAM OIDC provider.

eksctl utils associate-iam-oidc-provider --cluster eks-cluster --approve --profile eks-admin


2. Create Download IAM Policy:

curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

3. Create an IAM policy named AWSLoadBalancerControllerIAMPolicy.

aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam-policy.json --profile eks-admin


4. Create an IAM role and Kubernetes ServiceAccount for the LBC.

eksctl create iamserviceaccount --cluster eks-cluster --namespace kube-system --name aws-load-balancer-controller --attach-policy-arn arn:aws:iam::<account-id>:policy/AWSLoadBalancerControllerIAMPolicy --approve

# Detailed instructions¶
Follow the instructions in the aws-load-balancer-controller Helm chart.

1. Add the EKS chart repo to Helm

helm repo add eks https://aws.github.io/eks-charts
helm repo update

2. Helm install command for clusters with IRSA:

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-southeast-1 \
  --set vpcId=<vpc-id>

3. Verify  Controller
- kubectl get deployment -n kube-system aws-load-balancer-controller
- kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

## Appley green-bookinfo.yaml

## reapply bookinf-ingress.yaml by chaing traffing weighg .......
.....

# verify and test , traffic shiting 

## Deploy Osberavein with datadog 
1. Create Datadog Account
   -  Install Add on datadog operator in EKS Console or install by helm 
   -  Create secret 
      # kubectl create secret generic datadog-secret --from-literal api-key=xxxxx -n   datadog-agent
   -  Enable customize your observability coverage
   -  Create the datadog-agent.yaml file and Copy the context into it
      # kubectl apply -f datadog-agent.yaml

- [Datadog Helm Chart Documentation](https://app.datadoghq.com/fleet/install-agent/latest?platform=kubernetes&_gl=1*xlxlw8*_gcl_au*MTUxMDgxNjk2NC4xNzYzMDQ0MTc4LjYyNTI3ODM0LjE3NjM0Mzc1MDIuMTc2MzQzNzUxMQ..*_ga*MTE4MDUzMjQ5Mi4xNzYzNDM3MDgx*_ga_KN80RDFSQK*czE3NjM0MzcwODEkbzEkZzEkdDE3NjM0MzgxMTkkajEzJGwwJGgxOTc4MDA1NjUx)