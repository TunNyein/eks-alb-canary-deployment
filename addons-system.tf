# -----------------------------------------
# CoreDNS Add-on
# -----------------------------------------
resource "aws_eks_addon" "coredns" {
  cluster_name      = aws_eks_cluster.eks.name
  addon_name        = "coredns"
  
# let aws manage version Automatically 
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  

  depends_on = [
    aws_eks_node_group.eks_nodes
  ]
}

# -----------------------------------------
# VPC CNI Add-on
# -----------------------------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name      = aws_eks_cluster.eks.name
  addon_name        = "vpc-cni"
  
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

#   # VPC CNI uses its own IAM role
#   service_account_role_arn = aws_iam_role.vpc_cni_role.arn

  depends_on = [
    aws_eks_node_group.eks_nodes
  ]
}

# -----------------------------------------
# Kube Proxy Add-on
# -----------------------------------------
resource "aws_eks_addon" "kube_proxy" {
  cluster_name      = aws_eks_cluster.eks.name
  addon_name        = "kube-proxy"
  
 
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.eks_nodes
  ]
}
