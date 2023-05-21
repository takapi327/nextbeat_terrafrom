resource "aws_vpclattice_service_network" "microservice_network" {
  name      = "microservice-network"
  auth_type = "NONE"
}
