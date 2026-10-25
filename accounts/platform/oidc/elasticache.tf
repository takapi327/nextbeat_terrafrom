resource "aws_elasticache_subnet_group" "elasticache" {
  name       = "elasticache-subnet-group-${var.environment}"
  subnet_ids = [
    data.terraform_remote_state.platform.outputs.sn_private_1_id,
    data.terraform_remote_state.platform.outputs.sn_private_2_id,
    data.terraform_remote_state.platform.outputs.sn_private_3_id
  ]

  tags = {
    Name        = "elasticache-subnet-group-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_security_group" "elasticache" {
  name        = "elasticache-${var.environment}"
  description = "Security group for ElastiCache Redis"
  vpc_id      = data.terraform_remote_state.platform.outputs.vpc_id

  tags = {
    Name        = "sg-elasticache-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_security_group_rule" "elasticache_ingress" {
  security_group_id = aws_security_group.elasticache.id
  type              = "ingress"
  from_port         = 6379
  to_port           = 6379
  protocol          = "tcp"
  cidr_blocks       = [
    data.terraform_remote_state.platform.outputs.sn_private_1_cidr_block,
    data.terraform_remote_state.platform.outputs.sn_private_2_cidr_block,
    data.terraform_remote_state.platform.outputs.sn_private_3_cidr_block
  ]
  description       = "Allow Redis access from private subnets"
}

resource "aws_security_group_rule" "elasticache_egress" {
  security_group_id = aws_security_group.elasticache.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "redis-parameter-group-${var.environment}"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  tags = {
    Name        = "redis-parameter-group-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "redis-cluster-${var.environment}"
  description                = "Redis cluster for ${var.environment} environment"
  engine                     = "redis"
  node_type                  = "cache.t3.micro"
  num_cache_clusters         = 2
  parameter_group_name       = aws_elasticache_parameter_group.redis.name
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.elasticache.name
  security_group_ids         = [aws_security_group.elasticache.id]
  
  engine_version             = "7.0"
  automatic_failover_enabled = true
  multi_az_enabled           = true
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  snapshot_retention_limit   = 5
  snapshot_window            = "16:00-17:00"
  maintenance_window         = "sun:17:00-sun:18:00"
  
  notification_topic_arn     = aws_sns_topic.elasticache_notifications.arn
  
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.elasticache_slow_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.elasticache_engine_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = {
    Name        = "redis-cluster-${var.environment}"
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_log_group" "elasticache_slow_log" {
  name              = "/aws/elasticache/${var.environment}/slow-log"
  retention_in_days = 7

  tags = {
    Name        = "elasticache-slow-log-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "elasticache_engine_log" {
  name              = "/aws/elasticache/${var.environment}/engine-log"
  retention_in_days = 7

  tags = {
    Name        = "elasticache-engine-log-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_sns_topic" "elasticache_notifications" {
  name = "elasticache-notifications-${var.environment}"

  tags = {
    Name        = "elasticache-notifications-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticache_cpu" {
  alarm_name          = "elasticache-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "75"
  alarm_description   = "This metric monitors ElastiCache CPU utilization"
  alarm_actions       = [aws_sns_topic.elasticache_notifications.arn]

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  tags = {
    Name        = "elasticache-cpu-alarm-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticache_memory" {
  alarm_name          = "elasticache-memory-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ElastiCache memory usage"
  alarm_actions       = [aws_sns_topic.elasticache_notifications.arn]

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  tags = {
    Name        = "elasticache-memory-alarm-${var.environment}"
    Environment = var.environment
  }
}