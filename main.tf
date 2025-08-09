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

  # Disable KMS key creation
  create_kms_key            = false
  cluster_encryption_config = {}

  # Disable OIDC provider creation
  enable_irsa = false

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

      # Use managed policies only
      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonEKSWorkerNodePolicy         = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy              = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      }

      # Explicit role name to avoid conflicts
      iam_role_name = "eks-node-group-role"

      labels = {
        Environment = "dev"
        NodeGroup   = "main"
      }
    }
  }

  # Explicit cluster IAM role name
  iam_role_name = "eks-cluster-role"

  tags = var.tags
}

# Attach additional managed policies if needed
resource "aws_iam_role_policy_attachment" "cluster_additional" {
  role       = module.eks.cluster_iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "null_resource" "nodegroup_cleanup" {
  triggers = {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      aws eks list-nodegroups \
        --cluster-name ${self.triggers.cluster_name} \
        --region ${self.triggers.aws_region} \
        --query "nodegroups" \
        --output text | xargs -I {} \
        aws eks delete-nodegroup \
        --cluster-name ${self.triggers.cluster_name} \
        --nodegroup-name {} \
        --region ${self.triggers.aws_region} || true
      sleep 180
    EOT
  }
}
