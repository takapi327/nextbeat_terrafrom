data "aws_iam_role" "ecs_execution_role" {
  name = "ECSExecutionRole"
}

resource "aws_ecs_cluster" "product_b_cluster" {
  name = "productB-cluster"
}

resource "aws_service_discovery_private_dns_namespace" "product_b_service_discovery_namespace" {
  name = "productB.internal"
  vpc  = data.terraform_remote_state.product_b.outputs.product_b_vpc_id
}

resource "aws_service_discovery_service" "product_b_service_discovery" {
  name = "service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.product_b_service_discovery_namespace.id

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

resource "aws_ecs_task_definition" "fargate_spot_task" {
  family                   = "jvm-microservice-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  task_role_arn            = data.aws_iam_role.ecs_execution_role.arn
  execution_role_arn       = data.aws_iam_role.ecs_execution_role.arn
  cpu                      = 512
  memory                   = 1024
  container_definitions = jsonencode([
    {
      networkMode       = "awsvpc"
      essential         = true
      image             = "${data.aws_caller_identity.current.id}.dkr.ecr.ap-northeast-1.amazonaws.com/jvm-microservice-server:latest"
      memoryReservation = 1024
      name              = "jvm-microservice-server"
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
          awslogs-stream-prefix = "jvm-microservice-server"
          awslogs-region        = var.region
        }
      }
      portMappings = [
        {
          hostPort      = 9000
          containerPort = 9000
        }
      ]
      command = [
        "-Dconfig.file=conf/application.conf",
        "-Dlogback.configurationFile=conf/logback.xml"
      ]
    }
  ])
}


resource "aws_ecs_service" "product_b_service" {
  name             = "jvm-microservice-server"
  cluster          = aws_ecs_cluster.product_b_cluster.id
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
    target_group_arn = aws_lb_target_group.product_b_alb_target_group.arn
    container_name   = "jvm-microservice-server"
    container_port   = 9000
  }

  network_configuration {
    subnets          = [ data.terraform_remote_state.product_b.outputs.sn_private_1_id, ]
    security_groups  = [ aws_security_group.sg_ecs.id ]
    assign_public_ip = true
  }

  service_registries {
    container_port = 0
    port           = 0
    registry_arn   = aws_service_discovery_service.product_b_service_discovery.arn
  }

  task_definition = aws_ecs_task_definition.fargate_spot_task.arn

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
