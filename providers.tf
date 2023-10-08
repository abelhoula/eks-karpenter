provider "aws" {
  region = "us-east-1"
  alias  = "virginia"

  default_tags {
    tags = {
      Environment              = var.env
      resource_role            = "kubernetes"
      terraform                = "true"
      "karpenter.sh/discovery" = var.cluster_name[var.env]
    }
  }
}


data "aws_eks_cluster_auth" "default" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.default.token
  #exec {
  # api_version = "client.authentication.k8s.io/v1alpha1"
  #  command     = "aws"
  #   args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  #  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.default.token
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.default.token
}
