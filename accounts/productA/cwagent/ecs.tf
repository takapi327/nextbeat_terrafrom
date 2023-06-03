resource "aws_ecs_cluster" "cwagent_cluster" {
  name = "cwagent-cluster"
}

resource "aws_ecs_task_definition" "cwagent_prometheus" {
  family                   = "cloudwatch-agent-prometheus"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.cwagent_ecs_task_role.arn
  execution_role_arn       = aws_iam_role.cwagent_ecs_execution_role.arn
  cpu                      = 512
  memory                   = 1024
  container_definitions = jsonencode([
    {
      networkMode       = "awsvpc"
      essential         = true
      image             = "public.ecr.aws/cloudwatch-agent/cloudwatch-agent:1.247359.1b252618"
      memoryReservation = 1024
      name              = "cloudwatch-agent-prometheus"
      secrets = [
        {
          name:      "PROMETHEUS_CONFIG_CONTENT",
          valueFrom: aws_ssm_parameter.cloudwatch_agent_prometheus_config.name
        },
        {
          name: "CW_CONFIG_CONTENT",
          valueFrom: aws_ssm_parameter.cloudwatch_agent_config.name
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.cwagent_prometheus.name
          awslogs-stream-prefix = "cloudwatch-agent-prometheus"
          awslogs-region        = var.region
        }
      }
    }
  ])

  lifecycle {
    ignore_changes = [
      container_definitions
    ]
  }
}

resource "aws_ecs_service" "cwagent_prometheus" {
  name                = "cwagent-prometheus-replica-service"
  cluster             = aws_ecs_cluster.cwagent_cluster.id
  desired_count       = 1
  platform_version    = "LATEST"
  scheduling_strategy = "REPLICA"

  enable_execute_command             = true
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  network_configuration {
    subnets          = [ data.terraform_remote_state.product_a.outputs.sn_private_1_id ]
    security_groups  = [ aws_security_group.sg_cwagent_ecs.id ]
    assign_public_ip = true
  }

  task_definition = aws_ecs_task_definition.cwagent_prometheus.arn

  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition
    ]
  }
}
