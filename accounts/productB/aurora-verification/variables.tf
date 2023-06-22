variable "region" {
  description = "AWS region"
  default     = "ap-northeast-1"
}

variable "product_b_subnet_ips" {
  description = "List of subnet IPs managed by the ProductA account"
  type        = map(any)
}

variable "cloudfront_custom_header" {
  description = "Custom header values used by CloudFront and ALB"
  type        = string
}

variable "home_wifi" {
  description = "List of Home WIFI IPs"
  type = map(any)
}
