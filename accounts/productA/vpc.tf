resource "aws_vpc" "product_a_vpc" {
  cidr_block           = var.vpc_ips.productA
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name : "productA"
  }
}
