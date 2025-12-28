variable "aws_region" {
  type = string
  default = "ap-northeast-1"
}

variable "name_prefix" {
  type = string
  default = "finpay-otelcol"
}

variable "instance_type" {
  type = string
  default = "t3.large"
}

variable "ssh_key_name" {
  type = string
}

variable "allowed_cidrs" {
  type = list(string)
  description = "CIDRs allowed to access SSH/k8s (tighten this)"
}

variable "subnet_id" {
  type = string
  description = "Subnet ID to place EC2. You can use a public subnet."
}

variable "k3s_version" {
  type = string
  description = "Pinned k3s version (e.g. v1.29.8+k3s1)"
}
