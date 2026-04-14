variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "githubActions-EKS"
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "loadtest-api"
}

variable "github_iam_user_arn" {
  description = "ARN of the IAM user used by GitHub Actions"
  type        = string
  default     = "arn:aws:iam::231629457413:user/josejmosqueraf@unicauca.edu.co"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}
