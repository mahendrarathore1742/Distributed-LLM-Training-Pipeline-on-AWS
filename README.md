# Distributed LLM Training Pipeline on AWS

## 📋 Table of Contents
### Architecture Overview

1) Prerequisites

2) Project Structure

3) Deployment Steps

4) Usage Examples

5) Cost Management

6) Monitoring

7) Troubleshooting

8) Cleanup

## 🏗️ Architecture Overview
```+-----------------------------------------------------------------------+
|                         AWS Cloud Environment                         |
|                                                                       |
|  +---------------------+      +-----------------------------------+   |
|  |    VPC (10.0.0.0/16)|      |          EKS Cluster             |   |
|  |                     |      |                                   |   |
|  | +-----------------+ |      |  +-----------------------------+  |   |
|  | | Public Subnets  | |      |  |      Control Plane          |  |   |
|  | | (10.0.1.0/24)   |<----->|  |                             |  |   |
|  | | (10.0.2.0/24)   | |      |  +-----------------------------+  |   |
|  | +-----------------+ |      |                                   |   |
|  |                     |      |  +-----------------------------+  |   |
|  | +-----------------+ |      |  |        Worker Nodes         |  |   |
|  | | Private Subnets | |      |  |                             |  |   |
|  | | (10.0.101.0/24)|<----->|  | +-------------------------+ |  |   |
|  | | (10.0.102.0/24)| |      |  | | CPU Nodes (m5.xlarge)  | |  |   |
|  | +-----------------+ |      |  | +-------------------------+ |  |   |
|  |                     |      |  |                             |  |   |
|  | +-----------------+ |      |  | +-------------------------+ |  |   |
|  | |    NAT Gateway  | |      |  | | GPU Nodes (p4d.24xlarge)| |  |   |
|  | |                 | |      |  | | +---------------------+ | |  |   |
|  | +-----------------+ |      |  | | | NVIDIA A100 GPUs    | | |  |   |
|  |                     |      |  | | | (8 per instance)    | | |  |   |
|  +---------------------+      |  | | +---------------------+ | |  |   |
|                               |  | +-------------------------+ |  |   |
|                               |  +-----------------------------+  |   |
|                               |                                   |   |
|  +---------------------+      |  +-----------------------------+  |   |
|  |   FSx for Lustre    |<---->|  |    Kubernetes Resources     |  |   |
|  |  (High-performance  |      |  |                             |  |   |
|  |   shared storage)   |      |  | +-------------------------+ |  |   |
|  +---------------------+      |  | |      Training Jobs      | |  |   |
|                               |  | | (PyTorch + FSDP)        | |  |   |
|  +---------------------+      |  | +-------------------------+ |  |   |
|  |   S3 Bucket         |<---->|  |                             |  |   |
|  |  (Data & Models)    |      |  | +-------------------------+ |  |   |
|  +---------------------+      |  | |   vLLM Inference       | |  |   |
|                               |  | |      Service           | |  |   |
|                               |  | +-------------------------+ |  |   |
|                               |  +-----------------------------+  |   |
|                               +-----------------------------------+   |
+-----------------------------------------------------------------------+

```

## 📋 Prerequisites
### Before deploying this infrastructure, ensure you have:

1) AWS Account with appropriate permissions

2) AWS CLI configured with credentials

3) Terraform (v1.0.0 or later)

4) kubectl configured

5) Helm (v3.0 or later)

### Installation commands:

# Install AWS CLI (Linux)
``` curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Terraform (Linux)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install kubectl (Linux)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm (Linux)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

```

## 📁 Project Structure

``` llm-training-aws/
├── main.tf                 # Main Terraform configuration
├── providers.tf            # Terraform provider configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── terraform.tfvars.example # Example variables file
├── scripts/
│   └── user-data.sh        # User data script for GPU nodes
└── kubernetes/
    ├── namespace.yaml      # Kubernetes namespace
    ├── storage.yaml        # Storage class and PVC
    ├── training-job.yaml   # LLM training job
    └── vllm-service.yaml   # vLLM inference service

```

## 🚀 Deployment Steps

### Step 1: Clone and Configure

```
# Clone the repository (replace with your actual repo)
git clone https://github.com/your-username/llm-training-aws.git
cd llm-training-aws

# Configure your variables
cp terraform.tfvars.example terraform.tfvars

# Edit the variables file with your preferred editor
nano terraform.tfvars

```
Example terraform.tfvars:

```
aws_region = "us-west-2"
cluster_name = "llm-training-cluster"
gpu_instance_type = "p4d.24xlarge"
gpu_node_desired_size = 2
fsx_storage_size = 1200
```

###  Step 2: Initialize and Deploy Terraform

```
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply

# Confirm the action by typing 'yes'
```

### Step 3: Configure kubectl
```
# Configure kubectl to connect to your EKS cluster
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region $(terraform output -raw aws_region)

# Verify connection
kubectl get nodes
```

### Step 4: Deploy Kubernetes Resources
```
# Create the namespace
kubectl apply -f kubernetes/namespace.yaml

# Set up storage
kubectl apply -f kubernetes/storage.yaml

# Deploy the training job
kubectl apply -f kubernetes/training-job.yaml

# Deploy the inference service
kubectl apply -f kubernetes/vllm-service.yaml

```

### Step 5: Verify Deployment
```
# Check all resources
kubectl get all -n llm-training

# Check persistent volumes
kubectl get pv,pvc -n llm-training

# Check GPU resources
kubectl describe nodes | grep -i nvidia.com/gpu

# Check training job status
kubectl get jobs -n llm-training

# View training logs
kubectl logs -n llm-training job/llm-training-job --follow

```

## 💻 Usage Examples
### Upload Training Data to S3
```
# Get the S3 bucket name
S3_BUCKET=$(terraform output -raw s3_bucket_name)

# Upload training data
aws s3 sync ./training-data/ s3://$S3_BUCKET/input/

# Upload model checkpoints
aws s3 sync ./model-checkpoints/ s3://$S3_BUCKET/models/
```
### Monitor Training Progress
```
# Stream training logs
kubectl logs -n llm-training job/llm-training-job --follow

# Check resource usage
kubectl top pods -n llm-training
kubectl top nodes

# Describe pod for detailed information
kubectl describe pod -n llm-training <pod-name>

```
### Access the Inference Service

```
# Get the service URL
SERVICE_URL=$(kubectl get svc -n llm-training vllm-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test the inference endpoint
curl -X POST "http://$SERVICE_URL/v1/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llm-model",
    "prompt": "What is distributed training?",
    "max_tokens": 100,
    "temperature": 0.7
  }'

# For more complex queries
curl -X POST "http://$SERVICE_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llm-model",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Explain distributed training in simple terms."}
    ],
    "max_tokens": 150,
    "temperature": 0.7
  }'

  ```

### Scale Resources

```
# Scale GPU nodes (update desired count in terraform.tfvars first)
terraform apply

# Scale inference service
kubectl scale deployment vllm-inference --replicas=3 -n llm-training

# Check scaling status
kubectl get deployments -n llm-training
kubectl get nodes

```

## 💰 Cost Management

### Estimate Costs

```
# Check current resource usage and costs
# Note: Actual costs will vary based on usage

# GPU instance costs (approximate)
# p4d.24xlarge: ~$32-40 per hour
# p5.48xlarge: ~$98-120 per hour

# FSx for Lustre costs (approximate)
# 1.2TB: ~$1000 per month + throughput costs

# Calculate estimated monthly cost
# (2 x p4d.24xlarge instances) * 24 hours * 30 days = ~$46,000 - $57,600
# Plus storage and data transfer costs

```

### Cost Optimization Strategies

```
# Use spot instances for non-critical workloads
# Update variables.tf to use spot instances:
# capacity_type  = "SPOT"

# Implement auto-scaling
# Add to your node group configuration:
# scaling_config {
#   desired_size = 2
#   max_size     = 8
#   min_size     = 1
# }

# Schedule training during off-peak hours
# Use Kubernetes CronJobs for scheduled training:

# apiVersion: batch/v1
# kind: CronJob
# metadata:
#   name: nightly-training
#   namespace: llm-training
# spec:
#   schedule: "0 2 * * *"  # 2 AM daily
#   jobTemplate:
#     spec:
#       template:
#         spec:
#           containers:
#           - name: trainer
#             image: pytorch/pytorch:2.1.0-cuda11.8-cudnn8-devel
#             # ... rest of container spec

```

## 📊 Monitoring

### Set Up Monitoring

```
# Install Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin user for dashboard
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Create cluster role binding
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Get token for dashboard access
kubectl -n kubernetes-dashboard create token admin-user

# Access dashboard (run in separate terminal)
kubectl proxy

# Dashboard will be available at:
# http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

```

### Monitor GPU Utilization

```
# Install DCGM exporter for GPU monitoring
helm install prometheus-community/kube-prometheus-stack --generate-name \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Deploy NVIDIA DCGM exporter
kubectl create namespace monitoring
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/gpu-monitoring-tools/master/dcgm-exporter/dcgm-exporter.yaml -n monitoring

# Check GPU metrics
kubectl port-forward -n monitoring svc/dcgm-exporter 9400:9400
# Access metrics at http://localhost:9400/metrics

```

### Custom Monitoring Scripts

```
# Create a script to monitor training progress
cat > scripts/monitor-training.sh << 'EOF'
#!/bin/bash
NAMESPACE="llm-training"
JOB_NAME="llm-training-job"

echo "=== Training Job Status ==="
kubectl get jobs -n $NAMESPACE

echo -e "\n=== Pod Status ==="
kubectl get pods -n $NAMESPACE

echo -e "\n=== GPU Utilization ==="
kubectl describe nodes | grep -A 5 -B 5 "nvidia.com/gpu"

echo -e "\n=== Resource Usage ==="
kubectl top pods -n $NAMESPACE --containers
EOF

chmod +x scripts/monitor-training.sh

# Run the monitoring script
./scripts/monitor-training.sh

```

# 🐛 Troubleshooting

### Common Issues and Solutions

```
# Issue: Nodes not joining cluster
# Solution: Check IAM roles and security groups
aws eks describe-cluster --name $(terraform output -raw cluster_name) --region $(terraform output -raw aws_region) --query "cluster.resourcesVpcConfig.clusterSecurityGroupId"

# Issue: Pods pending due to insufficient resources
# Solution: Check resource requests and available nodes
kubectl describe pods -n llm-training
kubectl get nodes
kubectl describe nodes

# Issue: Cannot access FSx storage
# Solution: Check FSx status and security groups
aws fsx describe-file-systems --region $(terraform output -raw aws_region)
kubectl describe pvc -n llm-training fsx-claim

# Issue: NVIDIA drivers not working
# Solution: Check device plugin installation
kubectl get pods -n kube-system | grep nvidia
kubectl logs -n kube-system -l app=nvidia-device-plugin

# Issue: Training job failing
# Solution: Check logs and events
kubectl logs -n llm-training job/llm-training-job
kubectl get events -n llm-training --sort-by='.lastTimestamp'

```
### Debugging Commands

```
# Get detailed information about resources
kubectl describe -n llm-training job/llm-training-job
kubectl describe -n llm-training pod <pod-name>

# Check cluster events
kubectl get events -n llm-training --sort-by='.lastTimestamp'

# Check node conditions
kubectl describe nodes | grep -i conditions -A 10

# Check storage classes
kubectl get storageclass
kubectl describe storageclass fsx-sc

# Check persistent volumes
kubectl get pv
kubectl describe pv

# Check service account
kubectl describe serviceaccount -n llm-training training-job-sa

```

# 🧹 Cleanup

### Destroy Resources

```
# First, delete Kubernetes resources to avoid orphaned resources
kubectl delete -f kubernetes/ --recursive
kubectl delete namespace llm-training

# Then destroy Terraform resources
terraform destroy

# Confirm destruction by typing 'yes'

# Optional: Manually delete any remaining resources
aws s3 rb s3://$(terraform output -raw s3_bucket_name) --force

```

### Partial Cleanup

```
# If you want to keep some resources, use targeted destruction
terraform destroy -target=aws_eks_node_group.gpu_nodes
terraform destroy -target=aws_fsx_lustre_file_system.llm_storage

# To keep the EKS cluster but remove other resources
terraform destroy -target=aws_eks_node_group.gpu_nodes \
                 -target=aws_fsx_lustre_file_system.llm_storage \
                 -target=aws_s3_bucket.llm_data

```

# 📝 Additional Notes
### Performance Optimization

```
# For better performance, consider these optimizations:

# 1. Enable EFA (Elastic Fabric Adapter) for better network performance
#    Requires specific instance types and placement groups

# 2. Use larger instance types for better GPU-to-GPU communication
#    p4d.24xlarge (8x A100) or p5.48xlarge (8x H100)

# 3. Optimize FSx for Lustre configuration
#    Higher throughput tiers for better I/O performance

# 4. Use larger batch sizes and gradient accumulation
#    To maximize GPU utilization

# 5. Implement mixed precision training
#    Using torch.cuda.amp for faster training

```

### Security Considerations

```
# 1. Use private subnets for worker nodes
# 2. Implement network policies to restrict pod communication
# 3. Use IAM roles for service accounts with least privilege
# 4. Enable encryption at rest for S3 and FSx
# 5. Regularly rotate credentials and access keys
# 6. Use security groups to restrict network access
# 7. Enable AWS CloudTrail for auditing
# 8. Regularly update Kubernetes and node AMIs

```

This detailed README provides comprehensive instructions for setting up, using, and maintaining your distributed LLM training pipeline on AWS. The architecture is designed for scalability and performance while maintaining cost efficiency through spot instances and auto-scaling capabilities.

