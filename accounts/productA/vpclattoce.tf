resource "aws_vpclattice_service_network_vpc_association" "vpc_association" {
  vpc_identifier             = aws_vpc.product_a_vpc.id
  service_network_identifier = data.terraform_remote_state.platform.outputs.microservice_network_id
  security_group_ids = [
    aws_security_group.sg_alb.id
  ]
}

resource "aws_vpclattice_service" "product_a_service" {
  name      = "product-a-service"
  auth_type = "AWS_IAM"
}

resource "aws_vpclattice_service_network_service_association" "microservice_network_association" {
  service_identifier         = aws_vpclattice_service.product_a_service.id
  service_network_identifier = data.terraform_remote_state.platform.outputs.microservice_network_id
}
