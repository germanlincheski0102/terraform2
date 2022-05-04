# Example terragrunt.hcl
```
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  tags = merge(
    local.env_vars.locals.tags,
    local.additional_tags
  )
  env        = local.env_vars.locals.env
  account_id = local.env_vars.locals.account_vars.locals.account_id
  eks_cfg    = local.env_vars.locals.eks_cfg.default

  # Customize if needed
  additional_tags = {
  }
}

include {
  path = find_in_parent_folders()
}

terraform {
  source = "git@gitlab-art.globallogic.com.ar:practices/devops/terraform/tf-gl-main.git//0.14.x/eks?ref=eks-0.14-0.1.0"
}


dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  name                 = local.eks_cfg.eks_name
  vpc_id               = dependency.vpc.outputs.vpc_id
  subnet_ids           = slice(dependency.vpc.outputs.private_subnets, 0, length(dependency.vpc.outputs.availability_zones))
  tags                 = local.tags
  kubeconfig_file      = "${get_terragrunt_dir()}/kubeconfig"
  node_groups_defaults = local.eks_cfg.node_groups_defaults
  node_groups          = local.eks_cfg.node_groups
  map_roles            = local.eks_cfg.map_roles
  map_users            = local.eks_cfg.map_users

  cluster_enabled_log_types             = ["controllerManager", "api", "audit"]
  cluster_log_retention_in_days         = "90"
  cluster_endpoint_private_access_cidrs = local.env_vars.locals.external-deps.dependency.settings.outputs.vpn_cidrs
  tags                                  = local.tags
}
```

# Karpenter Node Autoscaling

Karpenter node autoscaling can be enabled for EKS clusters using this module in conjunction with Gitops changes to cluster. Instructions below.

## What is Karpenter?
- Karpenter is a replacement for the `cluster-autoscaler` controller. Do *not* use both concurrently.
- Karpenter can be used alongside node groups or in place of them, almost entirely. As far as I can tell (documentation is still scant), at least one, small node group must be created to deploy Karpenter into, when creating new clusters. After that, Karpenter can be left to handle provisioning of new nodes, independent of node groups.
- Requires EKS 1.20 or higher (documentation is scant on supported versions, but any lower and it refuses to install)
- Within K8S, Karpenter consists of a helm-deployed controller as well as a "provisioner"
- Upgrading the EKS module to version that creates Karpenter roles, policies, etc., should be safe to do at any time. As mentioned, however, do not deploy the Karpenter controller and provisioner (in Gitops) until the cluster autoscaler controller has been removed!
- The provisioner manifest can specify default instance types, zones, and other default settings for nodes. Pods, themselves, can request specific instance types, zones, etc., as long as they are among the choices permitted by provisioner.
- More details: https://github.com/aws/karpenter

## Overview of installation
(Scroll down for detailed Step-by-Step instructions)

### Preparation for existing clusters
1. Remove cluster-autoscaler yaml manifest from Gitops repo, but keep a local copy. Push the delete, then delete the corresponding resources with `kubectl remove -f <manifest>`.

### Preparation for new clusters
1. Create only one node group, min/max of 1/1 nodes.
1. Configure with Gitops/Flux as usual, but do not install `cluster-autoscaler` controller.

### Karpenter installation: Terraform
1. Edit `eks/terragrunt.hcl` to use a version of eks module in TF main that creates needed Karpenter resources.
1. Add an entry to `map_roles` to allow Karpenter-created nodes to talk to the cluster (in the exactly the same manner as nodes created by node groups do).

### Karpenter installation: Gitops
1. Edit new HelmRelease yaml for Karpenter controller, customizing as needed, then commit to Gitops repo to install.
1. Edit Karpenter provisioner.yaml, as needed, to specify the default zones, instance types, etc, allowed in the cluster. Commit to Gitops repo to install.

At within a few minutes, you should see pods for `karpenter-controller-*` and `karpenter-webhook-*`. Deploying new pods that exceed current CPU/memory of cluster should shortly result in new nodes being provisioned by Karpenter.

## Summary of resources created by Terraform
- Instance role and profile and attached policy.
    - The role is associated with nodes that Karpenter creates up.
    - The role and policy are very similar to that which associated with nodes created by node groups
- Service account role and policy (IRSA)
    - This links an IAM policy to the K8S Karpenter controller's service account, allowing it to create/delete nodes, etc.
- Service linked role
    - This is of the type `spot.amazonaws.com`
    - This role must exist if spot instances are desired
    - Only one of these can exist per AWS account, so if multiple cluster are created the EKS module inputs have an option to skip creation of this role.

## Detailed Step-by-step installation instructions
### Terraform
1. Create a new cluster with EKS terraform modules (the `ref` will change to pinned version once `eks-add-karpenter` is merged):
    - git@gitlab-art.globallogic.com.ar:practices/devops/terraform/tf-gl-main.git//0.14/eks?ref=eks-add-karpenter
1. If the the apply fails because the account already has a spot instance service linked role, specify this input:
```
  create_spot_service_linked_role = false
```
1. Once cluster is created/modified, make a note of these outputs:
    - `karpenter_service_account_role_arn`
    - `karpenter_node_role_arn`
    - `cluster_endpoint`
    - `cluster_id`
1. Edit and apply `eks/terragrunt.hcl` again, adding Karpenter node role to `map_roles`, changing `rolearn` to the value of TF output `karpenter_node_role_arn`:
    ```
    { 
      rolearn  = "arn:aws:iam::0123456789:role/KarpenterNodeRole-somecluster-nonprod"
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    },
    ```
### Gitops
1. In Gitops repo, create new helm release for Karpenter controller `karpenter-helmrelease.yaml` in appropriate location. This controller will deploy resources into the `kube-system` namespace`. Change:
    - `.spec.values.serviceAccount.annotations.eks.amazonaws.com/role-arn` to the value of TF output `karpenter_service_account_role_arn`
    - `.spec.values.controller.clusterEndpoint` to the value of TF output `cluster_endpoint` 
    - `.spec.values.controller.clusterName` to the value of TF output `cluster_id` 
    ```
    ---
    apiVersion: helm.fluxcd.io/v1
    kind: HelmRelease
    metadata:
      name: karpenter
      namespace: kube-system
    spec:
      releaseName: karpenter
      chart:
        #git: git@github.com:aws/karpenter
        git: https://github.com/aws/karpenter.git
        path: charts/karpenter
        ref: v0.5.1
      values:
        serviceAccount:
          # -- Create a service account for the application controller
          create: true
          # -- Service account name
          name: karpenter
          # -- Annotations to add to the service account (like the ARN of the IRSA role)
          annotations:
            eks.amazonaws.com/role-arn: arn:aws:iam::012345678900:role/somename-karpenter-service-account
        controller:
          # -- Additional environment variables to run with
          ## - name: AWS_REGION
          ## - value: eu-west-1
          env: []
          # -- Node selectors to schedule to nodes with labels.
          nodeSelector: {}
          # -- Tolerations to schedule to nodes with taints.
          tolerations: []
          # -- Affinity rules for scheduling
          affinity: {}
          # -- Image to use for the Karpenter controller
          image: "public.ecr.aws/karpenter/controller:v0.5.1@sha256:f992d8ae64408a783b019cd354265995fa3dd4445f22d793b0f8d520209a3e42"
          # -- Cluster name
          clusterName: "SOMENAME-karpenter-nonprod"
          # -- Cluster endpoint
          clusterEndpoint: "https://17D61A6334E152FC768FD2E7B1104544.gr7.us-east-1.eks.amazonaws.com"
          resources:
            requests:
              cpu: 1
              memory: 1Gi
            limits:
              cpu: 1
              memory: 1Gi
          replicas: 1
        webhook:
          # -- List of environment items to add to the webhook
          env: []
          # -- Node selectors to schedule to nodes with labels.
          nodeSelector: {}
          # -- Tolerations to schedule to nodes with taints.
          tolerations: []
          # -- Affinity rules for scheduling
          affinity: {}
          # -- Image to use for the webhook
          image: "public.ecr.aws/karpenter/webhook:v0.5.1@sha256:9358beeafd19d02de8c9bd20324a85f906eb7bd5da8db492339cfdec7059725b"
          # -- Set to true if using custom CNI on EKS
          hostNetwork: false
          port: 8443
          resources:
            limits:
              cpu: 100m
              memory: 50Mi
            requests:
              cpu: 100m
              memory: 50Mi
          replicas: 1
    ```
1. Add, commit and push `karpenter-helmrelease.yaml`.
1. In same directory as controller, create `provisioner.yaml`, changing:
    - `.spec.requirements`, as appropriate
    - `.spec.provider.instanceProfile` to the value of TF output `karpenter_node_role_arn`
    ```
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
        - key: "node.kubernetes.io/instance-type" 
          operator: In
          values: ["t3.large", "t3.medium"]
        - key: "topology.kubernetes.io/zone" 
          operator: In
          values: ["us-east-1a", "us-east-1b", "us-east-1c"]
        - key: "kubernetes.io/arch" 
          operator: In
          #values: ["arm64", "amd64"]
          values: ["amd64"]
        - key: "karpenter.sh/capacity-type"
          operator: In
          #values: ["spot", "on-demand"]
          values: ["on-demand"]
      limits:
        resources:
          cpu: 1000
      provider:
        instanceProfile: KarpenterNodeRole-somecluster-nonprod
      ttlSecondsAfterEmpty: 30
    ```
1. Add, commit, and push `provision.yaml`.
1. Done!
