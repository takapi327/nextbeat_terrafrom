/**
 * security for ALB
 */
resource "aws_security_group" "sg_alb" {
  name        = "security-alb"
  description = "Allow inbound"
  vpc_id      = data.terraform_remote_state.product_a.outputs.product_a_vpc_id

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
  vpc_id      = data.terraform_remote_state.product_a.outputs.product_a_vpc_id

  tags = {
    Name = "Security for ECS"
  }
}

resource "aws_security_group_rule" "sg_ecs_for_subnet" {
  security_group_id = aws_security_group.sg_ecs.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = [
    data.terraform_remote_state.product_a.outputs.sn_private_1_cidr_block
  ]
}

data "aws_ec2_managed_prefix_list" "vpclattice" {
  name = "com.amazonaws.${var.region}.vpc-lattice"
}

resource "aws_security_group_rule" "sg_ecs_for_80_prefix_list" {
  security_group_id = aws_security_group.sg_ecs.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.vpclattice.id]
}

resource "aws_security_group_rule" "sg_ecs_for_443_prefix_list" {
  security_group_id = aws_security_group.sg_ecs.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.vpclattice.id]
}

resource "aws_security_group_rule" "sg_ecs_egress_rule" {
  security_group_id = aws_security_group.sg_ecs.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  protocol          = "all"
}
