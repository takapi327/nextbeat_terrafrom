resource "aws_vpclattice_service_network_vpc_association" "vpc_association" {
  vpc_identifier             = data.terraform_remote_state.product_b.outputs.product_b_vpc_id
  service_network_identifier = data.terraform_remote_state.platform.outputs.microservice_network_id
  security_group_ids = [
    aws_security_group.sg_alb.id
  ]
}
