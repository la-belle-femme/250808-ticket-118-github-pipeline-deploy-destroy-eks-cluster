module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = var.vpc_id
  subnet_ids                     = var.subnet_ids
  cluster_endpoint_public_access = true

  # Disable CloudWatch logs completely
  create_cloudwatch_log_group = false
  cluster_enabled_log_types   = []

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    main = {
      name           = "main-node-group"
      instance_types = var.instance_types
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.desired_size
      key_name       = var.key_pair_name
      capacity_type  = "ON_DEMAND"

      # Use managed policies only (no inline policies)
      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonEKSWorkerNodePolicy         = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy              = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      }

      labels = {
        Environment = "dev"
        NodeGroup   = "main"
      }
    }
  }

  tags = var.tags
}