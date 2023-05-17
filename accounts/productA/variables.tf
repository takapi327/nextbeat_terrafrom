variable "region" {
  description = "AWS region"
  default     = "ap-northeast-1"
}

variable "vpc_ips" {
  description = "List of VPC IPs for accounts managed under Organization"
  type        = map(any)
}

variable "product_a_subnet_ips" {
  description = "List of subnet IPs managed by the ProductA account"
  type        = map(any)
}
