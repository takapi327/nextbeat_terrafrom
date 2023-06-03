resource "aws_cloudwatch_log_group" "cwagent_prometheus" {
  name = "/ecs/cwagent-prometheus"
}
