module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "19.16.0"

  cluster_name = var.cluster_name

  irsa_oidc_provider_arn          = var.eks_oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]
  create_iam_role                 = false
  iam_role_arn                    = var.iam_role_arn

  tags = {
    terraform_module_name    = basename(abspath(path.module))
    "karpenter.sh/discovery" = var.cluster_name
  }
}

resource "helm_release" "karpenter" {
  namespace           = var.karpenter_namespace
  create_namespace    = true
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = var.repository_username
  repository_password = var.repository_password
  chart               = "karpenter"
  version             = "v0.29.2"

  set {
    name  = "replicas"
    value = 1
  }

  set {
    name = "controller\\.resources"
    value = yamlencode({
      limits = {
        cpu    = "400m"
        memory = "500Mi"
      }
      requests = {
        cpu    = "200m"
        memory = "250Mi"
      }
    })
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }
  set {
    name  = "settings.aws.clusterName"
    value = var.cluster_name
  }
  set {
    name  = "settings.aws.clusterEndpoint"
    value = var.cluster_endpoint
  }
  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
  }
  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.queue_name
  }
}

################################################################################
# Karpenter Provionner & AWSNodeTemplate
################################################################################

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["t", "m"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["1", "2", "4"]
        - key: "karpenter.k8s.aws/instance-hypervisor"
          operator: In
          values: ["nitro"]
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: ${jsonencode(var.azs)}
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
        - key: "karpenter.sh/capacity-type" # If not included, the webhook for the AWS cloud provider will default to on-demand
          operator: In
          values: ["spot"]
      kubeletConfiguration:
        containerRuntime: containerd
        maxPods: 110
      limits:
        resources:
          cpu: 8
          memory: 10Gi
      consolidation:
        enabled: true
      providerRef:
        name: default
      ttlSecondsUntilExpired: 604800 # 7 Days = 7 * 24 * 60 * 60 Seconds
      #ttlSecondsAfterEmpty: 30  # If omitted, the feature is disabled, nodes will never scale down due to low utilization
  YAML
}

resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${var.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${var.cluster_name}
  YAML
}
