module "vpc-cni-service-account" {
  count                         = var.create_vpc_cni_role ? 1 : 0
  source                        = "git@gitlab-art.globallogic.com.ar:practices/devops/terraform/tf-gl-main.git//0.14.x/eks-service-account?ref=eks-service-account-0.14.x-0.1.0"
  service_account               = "aws-node"
  name_prefix                   = "vpc-cni-addon-${var.name}"
  cluster_id                    = module.cluster.cluster_id
  tags                          = var.tags
  provider_urls                 = [module.cluster.cluster_oidc_issuer_url]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:aws-node"]
  # Because the source module expects a primary policy
  primary_policy         = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "NoOp",
            "Effect": "Allow",
            "Action": "none:null",
            "Resource": "*"
        }
    ]
}
EOF
  additional_policy_arns = ["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]
}
