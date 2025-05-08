resource "aws_vpc" "platform_vpc" {
  cidr_block           = var.vpc_ips.platform
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name : "platform"
  }
}
