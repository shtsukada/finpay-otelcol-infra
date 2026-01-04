variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "name_prefix" {
  type    = string
  default = "finpay-otelcol"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.large"
}

variable "ssh_key_name" {
  type = string

  validation {
    condition     = length(trimspace(var.ssh_key_name)) > 0
    error_message = "ssh_key_name must not be empty."
  }
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to access SSH/k8s (tighten this)"

  validation {
    condition     = length(var.allowed_cidrs) > 0
    error_message = "allowed_cidrs must not be empty."
  }

  validation {
    condition     = alltrue([for c in var.allowed_cidrs : can(cidrhost(c, 0))])
    error_message = "allowed_cidrs must be valid CIDR strings."
  }

  validation {
    condition     = alltrue([for c in var.allowed_cidrs : c != "0.0.0.0/0" && c != "::/0"])
    error_message = "allowed_cidrs must not include 0.0.0.0/0 (or ::/0)."
  }
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID to place EC2. You can use a public subnet."

  validation {
    condition     = length(trimspace(var.subnet_id)) > 0
    error_message = "subnet_id must not be empty."
  }
}

variable "k3s_version" {
  type        = string
  description = "Pinned k3s version (e.g. v1.29.6+k3s1)"
  validation {
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+\\+k3s\\d+$", var.k3s_version))
    error_message = "k3s_version must look like:v1.29.6+k3s1"
  }
}

variable "k3s_disable_traefik" {
  type        = bool
  description = "Disable bundled Traefik ingress controller"
  default     = true
}
