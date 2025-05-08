/**
 * security for Aurora
 */
resource "aws_security_group" "aurora" {
  name        = "aurora"
  description = "Allow inbound Aurora"
  vpc_id      = aws_vpc.platform_vpc.id

  tags = {
    Name = "sg-aurora"
  }
}

resource "aws_security_group_rule" "aurora_ingress_rule" {
  security_group_id = aws_security_group.aurora.id
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = [
    aws_subnet.sn_private_1.cidr_block,
    aws_subnet.sn_private_2.cidr_block,
    aws_subnet.sn_private_3.cidr_block,
  ]
}

resource "aws_security_group_rule" "aurora_egress_rule" {
  security_group_id = aws_security_group.aurora.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
}

/**
 * security for Bastion
 */
resource "aws_security_group" "bastion" {
  name        = "bastion"
  description = "Bastion for Aurora"
  vpc_id      = aws_vpc.platform_vpc.id

  tags = {
    Name = "bastion"
  }
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
