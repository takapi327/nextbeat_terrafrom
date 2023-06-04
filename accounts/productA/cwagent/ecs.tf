resource "aws_ecs_cluster" "cwagent_cluster" {
  name = "cwagent-cluster"
}

resource "aws_service_discovery_private_dns_namespace" "jvm_server_service_discovery_namespace" {
  name = "jvm-server.internal"
  vpc  = data.terraform_remote_state.product_a.outputs.product_a_vpc_id
}


resource "aws_ecs_service" "stg_fargate_spot" {
  name             = aws_ecr_repository.jvm_server.name
  cluster          = aws_ecs_cluster.cwagent_cluster.id
  desired_count    = 1
  platform_version = "LATEST"

  enable_execute_command             = true
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  deployment_controller {
    type = "ECS"
  }

  tags = {}

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = aws_ecr_repository.jvm_server.name
    container_port   = 9000
  }

  network_configuration {
    subnets          = [data.terraform_remote_state.product_a.outputs.sn_private_1_id]
    security_groups  = [aws_security_group.sg_cwagent_ecs.id]
    assign_public_ip = true
  }

  service_registries {
    container_port = 0
    port           = 0
    registry_arn   = aws_service_discovery_service.jvm_server_service.arn
  }

  task_definition = aws_ecs_task_definition.jvm_server.arn

  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  health_check_grace_period_seconds = 0
  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition
    ]
  }
}

resource "aws_service_discovery_service" "jvm_server_service" {
  name = aws_ecr_repository.jvm_server.name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.jvm_server_service_discovery_namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "jvm_server" {
  family                   = aws_ecr_repository.jvm_server.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  cpu                      = 512
  memory                   = 1024
  container_definitions = jsonencode([
    {
      networkMode       = "awsvpc"
      essential         = true
      image             = "${data.aws_caller_identity.current.id}.dkr.ecr.ap-northeast-1.amazonaws.com/${aws_ecr_repository.jvm_server.name}:latest"
      memoryReservation = 1024
      name              = aws_ecr_repository.jvm_server.name
      environment = [
        {
          name  = "TZ"
          value = "Asia/Tokyo"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-stream-prefix = aws_ecr_repository.jvm_server.name
          awslogs-region        = "ap-northeast-1"
        }
      }
      portMappings = [
        {
          hostPort      = 9000
          containerPort = 9000
        },
        {
          hostPort      = 9090
          containerPort = 9090
        }
      ]
      command = [
        "-Dconfig.file=conf/application.conf",
        "-Dlogback.configurationFile=conf/logback.xml"
      ]
    }
  ])
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
          name : "PROMETHEUS_CONFIG_CONTENT",
          valueFrom : aws_ssm_parameter.cloudwatch_agent_prometheus_config.name
        },
        {
          name : "CW_CONFIG_CONTENT",
          valueFrom : aws_ssm_parameter.cloudwatch_agent_config.name
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
    subnets          = [data.terraform_remote_state.product_a.outputs.sn_private_1_id]
    security_groups  = [aws_security_group.sg_cwagent_ecs.id]
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
