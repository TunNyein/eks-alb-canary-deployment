#------------------------------------------------------------------------------
# EKS Security Groups
#------------------------------------------------------------------------------

                                                                     # Control Plane Security Group                             
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.vpc_prefix}-eks-cluster-sg"
  description = "EKS control plane security group"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_prefix}-eks-cluster-sg"
  }
}

# Allow all egress from Control Plane
resource "aws_vpc_security_group_egress_rule" "cluster_egress_all" {
  security_group_id = aws_security_group.eks_cluster_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}


# Nodes → Control Plane (all ports)
resource "aws_vpc_security_group_ingress_rule" "ingress_nodes_to_controlplane" {
  security_group_id            = aws_security_group.eks_cluster_sg.id
  referenced_security_group_id = aws_security_group.eks_node_sg.id
  # from_port                    = 0
  # to_port                      = 65535
  ip_protocol                  = "-1"
  description                  = "Allow worker nodes to communicate with control plane (all ports)"
}


                                                                     # Node Security Group
resource "aws_security_group" "eks_node_sg" {
  name        = "${var.vpc_prefix}-eks-node-sg"
  description = "EKS worker node security group"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_prefix}-eks-node-sg"
  }
}

# Allow all egress from Nodes
resource "aws_vpc_security_group_egress_rule" "node_egress_all" {
  security_group_id = aws_security_group.eks_node_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Control Plane → Nodes (all ports)
resource "aws_vpc_security_group_ingress_rule" "ingress_controlplane_to_nodes" {
  security_group_id            = aws_security_group.eks_node_sg.id
  referenced_security_group_id = aws_security_group.eks_cluster_sg.id
  # from_port                    = 0
  # to_port                      = 65535
  ip_protocol                  = "-1"
  description                  = "Allow control plane to communicate with worker nodes (all ports)"
}

# Nodes ↔ Nodes (all ports)
resource "aws_vpc_security_group_ingress_rule" "ingress_nodes_to_nodes" {
  security_group_id            = aws_security_group.eks_node_sg.id
  referenced_security_group_id = aws_security_group.eks_node_sg.id
  # from_port                    = 0
  # to_port                      = 65535
  ip_protocol                  = "-1"
  description                  = "Allow nodes to communicate with each other (all ports)"
}

