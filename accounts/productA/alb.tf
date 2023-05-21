resource "aws_alb" "product_a_internal_nlb" {
  name               = "productA-internal"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.sn_private_stg_1.id]

  enable_deletion_protection = false

  depends_on = [
    aws_vpc.product_a_vpc
  ]
}

resource "aws_lb_target_group" "product_a_nlb_target_group" {
  name                 = "productA-target-group"
  port                 = 80
  protocol             = "TCP"
  deregistration_delay = "300"
  proxy_protocol_v2    = false
  vpc_id               = aws_vpc.product_a_vpc.id
  target_type          = "ip"

  health_check {
    protocol = "TCP"
  }
}

resource "aws_lb_listener" "product_a_internal_nlb_443" {
  load_balancer_arn = aws_alb.product_a_internal_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product_a_nlb_target_group.arn
  }
}
