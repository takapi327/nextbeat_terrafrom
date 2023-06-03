resource "aws_alb" "product_a_internal_nlb" {
  name               = "productA-internal"
  internal           = true
  load_balancer_type = "network"
  subnets            = [data.terraform_remote_state.product_a.outputs.sn_private_1_id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "product_a_nlb_target_group" {
  name                 = "productA-target-group"
  port                 = 80
  protocol             = "TCP"
  deregistration_delay = "300"
  proxy_protocol_v2    = false
  vpc_id               = data.terraform_remote_state.product_a.outputs.product_a_vpc_id
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
