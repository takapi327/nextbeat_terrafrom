resource "aws_cloudwatch_log_group" "ecs" {
  name = "/ecs/logs"
}

resource "aws_cloudwatch_log_group" "vpclattice_service" {
  name = "/vpclattice/service/logs"
}
