/**
 * security for ALB
 */
resource "aws_security_group" "sg_alb" {
  name        = "security-alb"
  description = "Allow inbound"
  vpc_id      = data.terraform_remote_state.product_b.outputs.product_b_vpc_id

  tags = {
    Name = "Security for ALB"
  }
}

resource "aws_security_group_rule" "alb_443_ingress_rule" {
  security_group_id = aws_security_group.sg_alb.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_80_ingress_rule" {
  security_group_id = aws_security_group.sg_alb.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "sg_alb_egress_rule" {
  security_group_id = aws_security_group.sg_alb.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  protocol          = "all"
}

/**
 * security for ECS
 */
resource "aws_security_group" "sg_ecs" {
  name        = "security-ecs"
  description = "Allow inbound ECS"
  vpc_id      = data.terraform_remote_state.product_b.outputs.product_b_vpc_id

  tags = {
    Name = "Security for ECS"
  }
}

resource "aws_security_group_rule" "sg_ecs_for_alb_rule" {
  security_group_id        = aws_security_group.sg_ecs.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.sg_alb.id
}

resource "aws_security_group_rule" "sg_ecs_egress_rule" {
  security_group_id = aws_security_group.sg_ecs.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  protocol          = "all"
}

resource "aws_security_group" "aurora" {
  name        = "aurora"
  description = "Allow inbound Aurora"
  vpc_id      = data.terraform_remote_state.product_b.outputs.product_b_vpc_id

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
    var.product_b_subnet_ips.a_private,
    var.product_b_subnet_ips.b_private,
    var.product_b_subnet_ips.c_private
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
  vpc_id      = data.terraform_remote_state.product_b.outputs.product_b_vpc_id

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
