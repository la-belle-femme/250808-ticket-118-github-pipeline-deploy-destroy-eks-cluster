# github-oidc.tf

# Data source for existing OIDC provider
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Import existing IAM role
resource "aws_iam_role" "github_actions" {
  name               = "GitHubActions-EKS-Role"
  description        = "Role for GitHub Actions to manage EKS"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  tags               = var.tags
}

# Data source for existing policy
data "aws_iam_policy" "existing_ec2_permissions" {
  name = "GitHubActionsEKSEc2Permissions"
}

# Attach existing policy to role
resource "aws_iam_role_policy_attachment" "ec2_permissions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = data.aws_iam_policy.existing_ec2_permissions.arn
}

# Additional required permissions (if not in existing policy)
resource "aws_iam_policy" "additional_launch_template_perms" {
  name        = "GitHubActionsEKSExtraLaunchTemplatePerms"
  description = "Additional permissions for launch template management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeInstanceTypes"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "additional_perms" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.additional_launch_template_perms.arn
}

# Standard EKS policies
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}
