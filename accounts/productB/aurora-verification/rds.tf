resource "aws_rds_cluster" "cluster" {
  cluster_identifier              = "aurora-cluster-stg"
  engine                          = "aurora-mysql"
  engine_version                  = "5.7.mysql_aurora.2.07.2"
  database_name                   = "aurora_stg"
  master_username                 = "takapi327"
  master_password                 = "takapi327"
  backup_retention_period         = 35
  preferred_backup_window         = "16:10-16:40"
  preferred_maintenance_window    = "sun:17:10-sun:17:40"
  db_subnet_group_name            = aws_db_subnet_group.aurora_subnet_group.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.parameter.name
  storage_encrypted               = true
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  enabled_cloudwatch_logs_exports = ["audit", "error", "slowquery"]
  deletion_protection             = false // terraform destroy で削除できるようにするための設定(本番では使用しない)
  skip_final_snapshot             = true  // terraform destroy で削除できるようにするための設定(本番では使用しない)
  backtrack_window                = 86400
  lifecycle {
    ignore_changes = [master_password]
  }
}

resource "aws_rds_cluster_instance" "instance" {
  count                      = 2
  identifier                 = "aurora-cluster-stg-${count.index}"
  cluster_identifier         = aws_rds_cluster.cluster.id
  instance_class             = "db.t3.small"
  engine                     = aws_rds_cluster.cluster.engine
  engine_version             = aws_rds_cluster.cluster.engine_version
  db_parameter_group_name    = aws_db_parameter_group.parameter.name
  monitoring_interval        = 60
  monitoring_role_arn        = aws_iam_role.rds_monitoring.arn
  auto_minor_version_upgrade = false
}

resource "aws_rds_cluster_endpoint" "reader" {
  cluster_identifier          = aws_rds_cluster.cluster.id
  cluster_endpoint_identifier = "ro-con-stg"
  custom_endpoint_type        = "READER"
}

resource "aws_rds_cluster_parameter_group" "parameter" {
  name        = "rds-cluster-stg"
  family      = "aurora-mysql5.7"
  description = "RDS default cluster parameter group"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_results"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_connection"
    value = "utf8mb4_general_ci"
  }

  parameter {
    name  = "time_zone"
    value = "Asia/Tokyo"
  }

  parameter {
    name  = "general_log"
    value = 0
  }

  parameter {
    name  = "slow_query_log"
    value = 1
  }

  parameter {
    name  = "log_output"
    value = "file"
  }

  parameter {
    name  = "server_audit_events"
    value = "connect,query,query_dcl,query_ddl,query_dml,table"
  }

  parameter {
    name  = "server_audit_logging"
    value = "1"
  }

  parameter {
    name  = "server_audit_logs_upload"
    value = "1"
  }
}

resource "aws_db_parameter_group" "parameter" {
  name        = "db-stg"
  family      = "aurora-mysql5.7"
  description = "RDS default DB parameter group"

  parameter {
    name  = "max_connections"
    value = 1024
  }
}
