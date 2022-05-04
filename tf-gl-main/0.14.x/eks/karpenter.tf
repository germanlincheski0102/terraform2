# Service account related
resource "aws_iam_policy" "karpenter_policy" {
  name        = "${var.name}-karpenter-service-account"
  description = "Primary policy for karpenter service account in cluster ${var.name}"
  tags        = var.tags
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "Karpenter",
        "Effect": "Allow",
        "Action": [
           "ec2:CreateLaunchTemplate",
           "ec2:CreateFleet",
           "ec2:RunInstances",
           "ec2:CreateTags",
           "iam:PassRole",
           "ec2:TerminateInstances",
           "ec2:DescribeLaunchTemplates",
           "ec2:DescribeInstances",
           "ec2:DescribeSecurityGroups",
           "ec2:DescribeSubnets",
           "ec2:DescribeInstanceTypes",
           "ec2:DescribeInstanceTypeOfferings",
           "ec2:DescribeAvailabilityZones",
           "ssm:GetParameter"
        ],
        "Resource": "*"
      }
  ]
}
EOF
}
# Karpenter service account related
module "service_account_role" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "4.7.0"
  create_role                   = true
  role_name                     = "${var.name}-karpenter-service-account"
  tags                          = merge(var.tags, { Description = "Role with OIDC for attaching policies to EKS karpenter service account in cluster ${var.name}" })
  provider_urls                 = [module.cluster.cluster_oidc_issuer_url]
  role_policy_arns              = [aws_iam_policy.karpenter_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:karpenter"]
}

# Karpenter node role and instance profile
module "karpenter_node_role" {
  source            = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version           = "4.7.0"
  role_name         = "KarpenterNodeRole-${var.name}"
  create_role       = true
  role_requires_mfa = false
  trusted_role_services = [
    "ec2.amazonaws.com"
  ]
  create_instance_profile = true
  tags                    = var.tags
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}
# Service linked role used by Karpenter, if spot instances are needed
resource "aws_iam_service_linked_role" "role" {
  count            = var.create_spot_service_linked_role ? 1 : 0
  aws_service_name = "spot.amazonaws.com"
}

