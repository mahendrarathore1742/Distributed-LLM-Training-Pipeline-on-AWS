# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Get EKS cluster authentication
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Create VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = var.cluster_name
  }
}

# Create EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    cpu = {
      name         = "cpu-node"
      min_size     = 1
      max_size     = 5
      desired_size = 2
      instance_types = ["m5.xlarge"]
      capacity_type  = "ON_DEMAND"
    }
  }

  manage_aws_auth_configmap = true
}

# Create GPU node group
resource "aws_eks_node_group" "gpu_nodes" {
  cluster_name    = module.eks.cluster_name
  node_group_name = "gpu-nodes"
  node_role_arn   = module.eks.eks_managed_node_groups["cpu"].iam_role_arn
  subnet_ids      = module.vpc.private_subnets

  ami_type       = "AL2_x86_64_GPU"
  instance_types = [var.gpu_instance_type]
  capacity_type  = "SPOT"

  scaling_config {
    desired_size = var.gpu_node_desired_size
    max_size     = var.gpu_node_max_size
    min_size     = var.gpu_node_min_size
  }

  depends_on = [module.eks]
}

# Create FSx for Lustre filesystem
resource "aws_fsx_lustre_file_system" "llm_storage" {
  storage_capacity            = var.fsx_storage_size
  deployment_type             = "PERSISTENT_1"
  per_unit_storage_throughput = 200
  subnet_ids                  = [module.vpc.private_subnets[0]]
  security_group_ids          = [module.eks.cluster_primary_security_group_id]

  tags = {
    Name = "llm-training-storage"
  }
}

# Create S3 bucket for training data
resource "aws_s3_bucket" "llm_data" {
  bucket = "${var.cluster_name}-llm-data-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "LLM Training Data"
  }
}

# Create IAM role for training jobs
resource "aws_iam_role" "training_job_role" {
  name = "${var.cluster_name}-training-job-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
      }
    ]
  })
}

# Attach policies to IAM role
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.training_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "fsx_access" {
  role       = aws_iam_role.training_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonFSxReadOnlyAccess"
}

# Install NVIDIA device plugin
resource "helm_release" "nvidia_device_plugin" {
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  namespace  = "kube-system"
}

# Install FSx CSI Driver
resource "helm_release" "aws_fsx_csi_driver" {
  name       = "aws-fsx-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-fsx-csi-driver"
  chart      = "aws-fsx-csi-driver"
  namespace  = "kube-system"
}

# Create Kubernetes namespace
resource "kubernetes_namespace" "llm_training" {
  metadata {
    name = "llm-training"
  }
}

# Create Kubernetes service account
resource "kubernetes_service_account" "training_job_sa" {
  metadata {
    name      = "training-job-sa"
    namespace = kubernetes_namespace.llm_training.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.training_job_role.arn
    }
  }
}