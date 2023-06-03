output "product_a_vpc_id" {
  value = aws_vpc.product_a_vpc.id
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
