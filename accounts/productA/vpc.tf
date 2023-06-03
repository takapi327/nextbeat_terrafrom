resource "aws_vpc" "product_a_vpc" {
  cidr_block           = var.vpc_ips.productA
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name : "productA"
  }
}

data "aws_network_interface" "product_a_internal_nlb_network_interface" {
  filter {
    name   = "description"
    values = ["ELB ${aws_alb.product_a_internal_nlb.arn_suffix}"]
  }

  filter {
    name   = "subnet-id"
    values = [aws_subnet.sn_private_1.id, aws_subnet.sn_private_1.id]
  }
}
