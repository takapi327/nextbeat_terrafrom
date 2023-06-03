output "jvm_microservice_server_repository" {
  value = aws_ecr_repository.jvm_microservice_server.name
}

output "product_a_cluster_id" {
  value = aws_ecs_cluster.product_a_cluster.id
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

output "sg_ecs_id" {
  value = aws_security_group.sg_ecs.id
}
