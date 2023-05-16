data "terraform_remote_state" "platform" {
  backend = "remote"

  config = {
    organization = "takapi327"

    workspaces = {
      name = "platform"
    }
  }
}

resource "aws_vpclattice_service" "product_a_service" {
  name      = "product-a-service"
  auth_type = "AWS_IAM"
}

resource "aws_vpclattice_service_network_service_association" "microservice_network_association" {
  service_identifier         = aws_vpclattice_service.product_a_service.id
  service_network_identifier = data.terraform_remote_state.platform.outputs.microservice_network_id
}
