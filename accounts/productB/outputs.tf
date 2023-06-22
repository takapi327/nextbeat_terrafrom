output "product_b_vpc_id" {
  value = aws_vpc.product_b_vpc.id
}

output "product_b_vpc_default_security_group_id" {
  value = aws_vpc.product_b_vpc.default_security_group_id
}

output "sn_private_1_id" {
  value = aws_subnet.sn_private_1.id
}

output "sn_private_2_id" {
  value = aws_subnet.sn_private_2.id
}

output "sn_private_3_id" {
  value = aws_subnet.sn_private_3.id
}

output "sn_private_1_cidr_block" {
  value = aws_subnet.sn_private_1.cidr_block
}

output "sn_global_1_id" {
  value = aws_subnet.sn_global_1.id
}

output "sn_global_2_id" {
  value = aws_subnet.sn_global_2.id
}

output "sn_global_3_id" {
  value = aws_subnet.sn_global_3.id
}
