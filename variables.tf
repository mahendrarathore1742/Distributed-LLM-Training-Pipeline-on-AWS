variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "llm-training-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.27"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "gpu_instance_type" {
  description = "GPU instance type"
  type        = string
  default     = "p4d.24xlarge"
}

variable "gpu_node_desired_size" {
  description = "GPU nodes desired size"
  type        = number
  default     = 2
}

variable "gpu_node_min_size" {
  description = "GPU nodes min size"
  type        = number
  default     = 1
}

variable "gpu_node_max_size" {
  description = "GPU nodes max size"
  type        = number
  default     = 8
}

variable "fsx_storage_size" {
  description = "FSx storage size in GB"
  type        = number
  default     = 1200
}