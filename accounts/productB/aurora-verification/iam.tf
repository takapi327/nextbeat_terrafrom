/**
 * Aurora用 ロール
 */
resource aws_iam_role rds_monitoring {
  name               = "rds-monitoring-role"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume_role.json
}

data aws_iam_policy_document rds_monitoring_assume_role {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = [
        "monitoring.rds.amazonaws.com"
      ]
    }
  }
}

resource aws_iam_role_policy_attachment aws_rds_enhanced_monitoring_role {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.rds_monitoring.name
}

/**
 * 踏み台サーバー用 ロール
 */
data "aws_iam_policy_document" "ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "EC2BastionRole"
  assume_role_policy = data.aws_iam_policy_document.ec2.json
}

resource "aws_iam_instance_profile" "bastion" {
  name = "EC2BastionRole"
  role = aws_iam_role.bastion.name
}

resource "aws_iam_role_policy_attachment" "bastion_ssm_policy_attach" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "bastion_cloudwatch_policy_attach" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
