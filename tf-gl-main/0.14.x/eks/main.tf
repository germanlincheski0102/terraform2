data "aws_eks_cluster" "cluster" {
  name = module.cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.cluster.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

module "cluster" {
  source                                         = "terraform-aws-modules/eks/aws"
  version                                        = "14.0.0"
  cluster_name                                   = var.name
  cluster_version                                = var.cluster_version
  subnets                                        = var.subnet_ids
  vpc_id                                         = var.vpc_id
  cluster_endpoint_private_access                = var.cluster_endpoint_private_access
  cluster_endpoint_private_access_cidrs          = var.cluster_endpoint_private_access_cidrs
  cluster_create_endpoint_private_access_sg_rule = var.cluster_create_endpoint_private_access_sg_rule
  cluster_endpoint_public_access                 = var.cluster_endpoint_public_access
  cluster_enabled_log_types                      = var.cluster_enabled_log_types
  cluster_log_retention_in_days                  = var.cluster_log_retention_in_days
  tags                                           = var.tags
  map_roles                                      = var.map_roles
  map_users                                      = var.map_users
  node_groups                                    = var.node_groups
  node_groups_defaults                           = var.node_groups_defaults
  workers_additional_policies                    = concat([module.policy_ecr.arn], var.workers_additional_policies)
  kubeconfig_aws_authenticator_additional_args   = var.kubeconfig_aws_authenticator_additional_args
  enable_irsa                                    = var.enable_irsa

  wait_for_cluster_cmd = (var.wait_for_cluster_cmd != "") ? var.wait_for_cluster_cmd : null
}

resource "local_file" "kubeconfig" {
  content         = module.cluster.kubeconfig
  filename        = var.kubeconfig_file
  file_permission = "0600"
}

module "policy_ecr" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "3.7.0"

  name        = "${var.name}AuthorizeECR"
  description = "Allow ECR access from EKS cluster"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "ecr:GetAuthorizationToken",
        "Resource" : "*"
      }
    ]
  })
}
