# Install the Datadog Agent on Kubernetes with fleet automation

https://app.datadoghq.com/fleet/install-agent/latest?platform=kubernetes&_gl=1*xlxlw8*_gcl_au*MTUxMDgxNjk2NC4xNzYzMDQ0MTc4LjYyNTI3ODM0LjE3NjM0Mzc1MDIuMTc2MzQzNzUxMQ..*_ga*MTE4MDUzMjQ5Mi4xNzYzNDM3MDgx*_ga_KN80RDFSQK*czE3NjM0MzcwODEkbzEkZzEkdDE3NjM0MzgxMTkkajEzJGwwJGgxOTc4MDA1NjUx

- Create Datadog Account 
- Install Add on DATA Operation in EKS Console 

- Create secret 

# kubectl create secret generic datadog-secret --from-literal api-key=6ec7cd605ddd2e12d9fdd2e582dd -n datadog-agent

# Apply Datadog agent yaml 


# update kubeconfig for eks admin

aws eks update-kubeconfig --region ap-southeast-1 --name eks-cluster --alias eks-admin --profile eks-admin

# verify cluster access
1. kubectl get ns 
2. kubectl get all -n kube-system

# Create namespaces
kubectl create ns details
kubectl create ns reviews
kubectl create ns ratings
kubectl create ns productpage

# Apply access entry 
 terraform apply --auto-approve 

# Apply rbac.yaml

kubectl apply -f rbac.yaml

# configure aws IAM profiles for junior & lead ops engineers 

# update kubeconfig for junior & Lead ops engineers
1. aws eks update-kubeconfig --region ap-southeast-1 --name eks-cluster --alias junior-ops-engineer --profile junior-ops-engineer

2. aws eks update-kubeconfig --region ap-southeast-1 --name eks-cluster --alias lead-ops-engineer --profile lead-ops-engineer

# check contexts
kubectl config get-contexts

# verify permission on each namesapce 

![alt text](<Screenshot from 2025-11-20 22-53-34.png>)


# Run micro services at their respective namespace by applying blue-bookinfo.yaml
kubectl apply -f blue-bookinfo.yaml
# apply externa svc.yaml to producate namespace 
kubectl apply -f external-svc.yaml 

# apply bokinfo-ingress.yaml under producate namespace
kubectl apply -f bokinfo-ingress.yaml


# Install AWS Load Balancer Controller

### installation guide : https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/

1. Create an IAM OIDC provider.

eksctl utils associate-iam-oidc-provider --cluster eks-cluster --approve --profile eks-admin


2. Create IAM policy for the controller:

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

############################3

  

# Apply gree-bookinfo.yaml 

# Reapply bookinfo-ingress.yaml

helm uninstall aws-load-balancer-controller -n kube-system

$ kubectl get ingress -n productpage
NAME               CLASS   HOSTS                 ADDRESS                                                                       PORTS   AGE
bookinfo-ingress   alb     bookinfo.tunlab.xyz   k8s-productp-bookinfo-a1e73bb215-747657617.ap-southeast-1.elb.amazonaws.com   80      96m
$ kubectl delete  ingress bookinfo-ingress -n productpage
ingress.networking.k8s.io "bookinfo-ingress" deleted