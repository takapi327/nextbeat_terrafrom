resource "aws_vpclattice_service_network_vpc_association" "vpc_association" {
  vpc_identifier             = aws_vpc.product_a_vpc.id
  service_network_identifier = data.terraform_remote_state.platform.outputs.microservice_network_id
  security_group_ids = [
    aws_security_group.sg_alb.id
  ]
}

resource "aws_vpclattice_service" "product_a_service" {
  name      = "product-a-service"
  auth_type = "NONE"
}

resource "aws_vpclattice_access_log_subscription" "product_a_service_access_log" {
  resource_identifier = aws_vpclattice_service.product_a_service.id
  destination_arn     = aws_cloudwatch_log_group.vpclattice_service.arn
}

resource "aws_vpclattice_service_network_service_association" "microservice_network_association" {
  service_identifier         = aws_vpclattice_service.product_a_service.id
  service_network_identifier = data.terraform_remote_state.platform.outputs.microservice_network_id
}

resource "aws_vpclattice_target_group" "product_a_service_target" {
  name = "product-a-service-target"
  type = "IP"

  config {
    port             = 80
    protocol         = "HTTP"
    vpc_identifier   = aws_vpc.product_a_vpc.id
    protocol_version = "GRPC"
  }
}

resource "aws_vpclattice_target_group_attachment" "product_a_service_target_attachment" {
  target_group_identifier = aws_vpclattice_target_group.product_a_service_target.id

  target {
    id   = data.aws_network_interface.product_a_internal_nlb_network_interface.private_ip
    port = 80
  }
}

resource "aws_vpclattice_listener" "product_a_service_listener" {
  name               = "product-a-service-listener"
  protocol           = "HTTPS"
  port               = 443
  service_identifier = aws_vpclattice_service.product_a_service.id

  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.product_a_service_target.id
      }
    }
  }
}
