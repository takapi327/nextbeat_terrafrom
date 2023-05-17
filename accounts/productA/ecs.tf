resource aws_ecs_cluster product_a_cluster {
  name = "productA-cluster"
}

resource aws_service_discovery_private_dns_namespace product_a_service_discovery_namespace {
  name = "productA.internal"
  vpc  = aws_vpc.product_a_vpc.id
}

resource aws_service_discovery_service product_a_service_discovery {
  name = "service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.product_a_service_discovery_namespace.id

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

resource aws_ecs_task_definition fargate_spot_task {
  family                   = aws_ecr_repository.jvm_microservice_server.name
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
      image             = "${data.aws_caller_identity.current.id}.dkr.ecr.ap-northeast-1.amazonaws.com/${aws_ecr_repository.jvm_microservice_server.name}:latest"
      memoryReservation = 1024
      name              = aws_ecr_repository.jvm_microservice_server.name
      environment       = [
        {
          name  = "TZ"
          value = "Asia/Tokyo"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-stream-prefix = aws_ecr_repository.jvm_microservice_server.name
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
