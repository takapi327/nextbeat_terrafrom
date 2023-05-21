resource "aws_vpclattice_service_network" "microservice_network" {
  name      = "microservice-network"
  auth_type = "NONE"
}

resource "aws_vpclattice_access_log_subscription" "microservice_network_access_log" {
  resource_identifier = aws_vpclattice_service_network.microservice_network.id
  destination_arn     = aws_cloudwatch_log_group.vpclattice.arn
}
