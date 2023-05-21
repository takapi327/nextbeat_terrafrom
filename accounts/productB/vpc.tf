resource "aws_vpc" "product_b_vpc" {
  cidr_block           = var.vpc_ips.productB
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name : "productB"
  }
}
