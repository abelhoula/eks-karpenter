# eks-karpenter

## Prerequisites:

* AWS CLI installed and configured with appropriate credentials.
* Terraform installed on your local machine.


## Description
This Terraform code will create:

1) Networking Infrastructure:
    * A Virtual Private Cloud (VPC) with public and private subnets.
    * NAT Gateways for private subnets to enable outbound internet access.

2) Amazon EKS Cluster:

    * An Amazon Elastic Kubernetes Service (EKS) cluster.
    * OIDC (OpenID Connect) authentication enabled for secure identity integration.
    * A node group within the EKS cluster.

3) Karpenter Integration:
    * An IAM role for secure access between Karpenter and AWS services.
    * Deployment and configuration of Karpenter, an autoscaling solution for Kubernetes.
    Scaling policies and settings for optimized resource management.

## Deploy
terraform init
terraform plan
terraform apply