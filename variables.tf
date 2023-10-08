variable "region" {
  description = "AWS Region"
  default     = "us-east-1"
}

# SET THESE ROLES TO YOUR TERRAFORM ROLES PER ACCOUNT
variable "role_name" {
  description = "Role ARN"
  type        = map(string)

  default = {
    dev  = "TerraformTester"
    uat  = "TerraformTester"
    prod = "TerraformTester"
  }
}

variable "admin_iam_group" {
  description = "Group name"
  type        = map(string)

  default = {
    dev  = "TerraformTesters"
    uat  = "TerraformTesters"
    prod = "TerraformTesters"
  }
}

variable "env" {
  description = "Environment"
  type        = string
}


variable "availability_zones" {
  description = "Availability Zones to Use"
  type = object({
    dev  = list(string),
    prod = list(string),
  })

  default = {
    dev  = ["us-east-1a", "us-east-1b"]
    uat  = ["us-east-1a", "us-east-1b"]
    prod = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway or multiple"
  type        = map(string)

  default = {
    dev  = true
    prod = true # false
  }
}

## EKS Variables
variable "cluster_name" {
  description = "Name for EKS Cluster"
  type        = map(string)
  default = {
    dev  = "dev-eks-cluster"
    prod = "prod-eks-cluster"
  }
}

variable "cluster_version" {
  description = "EKS Cluster Version to use"
  type        = map(string)

  default = {
    dev  = 1.24
    prod = 1.24
  }
}

variable "instance_types" {
  description = "Instance types to use in nodegroup"
  type = object({
    dev  = list(string),
    prod = list(string),
  })

  default = {
    dev  = ["t2.medium", "t2.small"]
    prod = ["m5.xlarge", "m5.2xlarge", "m4.xlarge"]
  }
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap."
  type        = list(string)

  default = []
}

variable "asg_min_size" {
  description = "Autoscaling group min size"
  type        = map(string)

  default = {
    dev  = 1
    uat  = 1 # 3
    prod = 3
  }
}

variable "asg_desired_capacity" {
  description = "Autoscaling group desired size"
  type        = map(string)

  default = {
    dev  = 1 # 2
    uat  = 1 # 3
    prod = 3
  }
}

variable "on_demand_base_capacity" {
  description = "Autoscaling group on-demand base capacity"
  type        = map(string)

  default = {
    dev  = 0
    uat  = 0 #1
    prod = 3
  }
}

variable "on_demand_percentage_above_base_capacity" {
  description = "Autoscaling group on-demand percentage above base capacity"
  type        = map(string)

  default = {
    dev  = 0
    uat  = 0
    prod = 25
  }
}

variable "asg_max_size" {
  description = "Autoscaling group max size"
  type        = map(string)

  default = {
    dev  = 2
    uat  = 2 #9
    prod = 9
  }
}

variable "spot_instance_pools" {
  description = "Autoscaling group number of spot instance pools"
  type        = map(string)

  default = {
    dev  = 1 # 3
    prod = 3
  }
}


variable "karpenter_namespace" {
  description = "karpenter namespace"
  type        = string
  default     = "karpenter"
}
