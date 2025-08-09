module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = var.vpc_id
  subnet_ids                     = var.subnet_ids
  cluster_endpoint_public_access = true

  create_cloudwatch_log_group = false
  cluster_enabled_log_types   = []

  create_kms_key            = false
  cluster_encryption_config = {}

  enable_irsa = false

  eks_managed_node_groups = {
    main = {
      name           = "main-node-group"
      instance_types = var.instance_types
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.desired_size
      key_name       = var.key_pair_name
      capacity_type  = "ON_DEMAND"

      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonEKSWorkerNodePolicy         = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy              = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      }

      iam_role_name = "eks-node-group-role"
      labels = {
        Environment = "dev"
        NodeGroup   = "main"
      }
    }
  }

  iam_role_name = "eks-cluster-role"
  tags          = var.tags
}

# Move these resources outside the module's dependency chain
resource "aws_iam_role_policy_attachment" "cluster_additional" {
  role       = module.eks.cluster_iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Create the destroy policy for the node role, not the cluster role
resource "aws_iam_role_policy" "github_actions_destroy" {
  name = "GitHubActions-EKS-Destroy-Policy"
  role = module.eks.eks_managed_node_groups["main"].iam_role_name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "eks:UpdateNodegroupConfig",
          "eks:ListNodegroups",
          "eks:DeleteNodegroup",
          "eks:DescribeNodegroup",
          "cloudformation:DescribeStacks",
          "cloudformation:DeleteStack"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "time_sleep" "wait_for_nodegroup_deletion" {
  depends_on = [
    module.eks,
    aws_iam_role_policy.github_actions_destroy
  ]
  
  destroy_duration = "15m"

  triggers = {
    cluster_name = module.eks.cluster_name
  }
}
