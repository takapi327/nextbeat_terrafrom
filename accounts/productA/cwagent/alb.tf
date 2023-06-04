resource "aws_alb" "jvm_server" {
  name               = "jvm-server"
  internal           = false
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.sg_cwagent_alb.id,
    data.terraform_remote_state.product_a.outputs.product_a_vpc_default_security_group_id
  ]
  subnets = [
    data.terraform_remote_state.product_a.outputs.sn_private_1_id,
    data.terraform_remote_state.product_a.outputs.sn_global_2_id
  ]

  enable_deletion_protection = false
}

resource "aws_lb_listener" "alb_80" {
  load_balancer_arn = aws_alb.jvm_server.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      status_code  = "403"
      message_body = "Connection is not allowed."
    }
  }
}

resource "aws_lb_listener_rule" "alb_80_rule" {
  listener_arn = aws_lb_listener.alb_80.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

  condition {
    http_header {
      http_header_name = "X-From-Restriction-Cloudfront"
      values           = [var.cloudfront_custom_header]
    }
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

resource "aws_lb_target_group" "target_group" {
  name                 = "target-group"
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = "300"
  proxy_protocol_v2    = false
  vpc_id               = data.terraform_remote_state.product_a.outputs.product_a_vpc_id
  target_type          = "ip"

  health_check {
    path                = "/healthcheck"
    healthy_threshold   = 5
    interval            = 30
    unhealthy_threshold = 2
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
  }
}
