data "aws_availability_zones" "available" {}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 4)
}

# ----- CLUSTER SUBNETS -----
module "eks_network" {
  source         = "./modules/network"
  vpc_id         = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_cidr_block = data.terraform_remote_state.vpc.outputs.vpc_cidr_block
  cidr_block_igw = "0.0.0.0/0"
  igway_id       = data.terraform_remote_state.vpc.outputs.igway_id
  eip_id         = data.terraform_remote_state.vpc.outputs.eip_id
  cluster_name   = var.cluster_name[var.env]
  azs            = var.availability_zones[var.env]
}

# ----- CLUSTER -----
module "eks" {
  # Module pulled from https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "~> 18.0"
  cluster_name                    = var.cluster_name[var.env]
  cluster_version                 = var.cluster_version[var.env]
  subnet_ids                      = module.eks_network.private_subnet_ids
  vpc_id                          = data.terraform_remote_state.vpc.outputs.vpc_id
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  enable_irsa                     = true
  manage_aws_auth_configmap       = true


  aws_auth_roles = [
    {
      rolearn  = module.eks_karpenter.karpenter_irsa_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:nodes", "system:bootstrappers"]
    }
  ]

  aws_auth_users = [
    for user in data.aws_iam_group.developers.users : {
      userarn  = user.arn
      username = user.user_name
      groups   = ["system:masters"]
    }
  ]

  eks_managed_node_group_defaults = {
    # We are using the IRSA created below for permissions However, we have to provision a new cluster with
    # the policy attached FIRST before we can disable. Without this initial policy, the VPC CNI fails to
    # assign IPs and nodes cannot join the new cluster
    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    "${var.env}-primary" = {
      min_size       = var.asg_min_size[var.env]
      max_size       = var.asg_max_size[var.env]
      desired_size   = var.asg_desired_capacity[var.env]
      instance_types = var.instance_types[var.env]
      capacity_type  = "SPOT"
      tags = {
        "kubernetes.io/cluster/${var.cluster_name[var.env]}" = "owned"
      }
    }
  }
  node_security_group_tags = {
    "kubernetes.io/cluster/${var.cluster_name[var.env]}" = null # or any other value other than "owned"
  }
  node_security_group_additional_rules = {
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
    apiext_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to emissary-apiext"
    }

    allow_all_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      source_cluster_security_group = true
      description                   = "Allow access from control plane to all ports"
    }
    # api_services_allow_https_access = {
    #   type                          = "ingress"
    #   protocol                      = "tcp"
    #   from_port                     = 443
    #   to_port                       = 443
    #   source_cluster_security_group = true
    #   description                   = "Allow HTTPS access from control plane to api services"
    # }
    allow_all_egress = {
      type             = "egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      description      = "Allow all egress"
    }
  }

  tags = {
    terraform_module_name    = basename(abspath(path.module))
    "karpenter.sh/discovery" = var.cluster_name[var.env]
  }
  #cluster_tags = {
  #  "kubernetes.io/cluster/${var.cluster_name[var.env]}" = null # or any other value other than "owned"
  # }
}

################################################################################
# Karpenter
################################################################################
module "eks_karpenter" {
  source                = "./modules/karpenter"
  cluster_name          = var.cluster_name[var.env]
  cluster_endpoint      = module.eks.cluster_endpoint
  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  iam_role_arn          = module.eks.eks_managed_node_groups["${var.env}-primary"].iam_role_arn
  karpenter_namespace   = var.karpenter_namespace
  azs                   = local.azs
  repository_username   = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password   = data.aws_ecrpublic_authorization_token.token.password
}
