#------------------------------------------------------------------------------
#  Lead and Junior Engineers IAM Users
#------------------------------------------------------------------------------

resource "aws_iam_user" "lead_ops_engineer" {
  name = "lead-Ops-engineer"
}

resource "aws_iam_user" "junior_ops_engineer" {
  name = "junior-Ops-engineer"
}

#------------------------------------------------------------------------------
# IAM Policy to Allow EKS DescribeCluster Action 
#------------------------------------------------------------------------------

resource "aws_iam_policy" "eks_describe" {
  name        = "eks-describe-cluster"
  description = "Allow users to describe EKS clusters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = "*"
      }
    ]
  })
}

#------------------------------------------------------------------------------
# Attach IAM Policy to Users
#------------------------------------------------------------------------------ 

resource "aws_iam_user_policy_attachment" "lead_iam_attach" {
  user       = aws_iam_user.lead_ops_engineer.name
  policy_arn = aws_iam_policy.eks_describe.arn
}

resource "aws_iam_user_policy_attachment" "junior_iam_attach" {
  user       = aws_iam_user.junior_ops_engineer.name
  policy_arn = aws_iam_policy.eks_describe.arn
}

# # ACCESS KEYS (destroy works)
# resource "aws_iam_access_key" "lead_access_key" {
#   user = aws_iam_user.lead_ops_engineer.name
# }

# resource "aws_iam_access_key" "junior_access_key" {
#   user = aws_iam_user.junior_ops_engineer.name
# }
