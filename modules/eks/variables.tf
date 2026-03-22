variable "cluster_name" {}
variable "vpc_id" {}
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "cluster_role_arn" {}
variable "node_role_arn" {}
variable "ssh_key_name" {}

variable "additional_security_group_ids_for_cluster" {
  description = "List of additional security group IDs to allow access to the EKS cluster control plane on port 443."
  type        = list(string)
  default     = []
}

variable "jenkins_role_arn" {
  description = "ARN của Jenkins IAM Role để cấp quyền admin trong EKS"
  type        = string
}
