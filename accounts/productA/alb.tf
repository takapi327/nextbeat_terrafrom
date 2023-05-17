resource "aws_alb" "product_a_alb" {
  name               = "productA"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id, aws_vpc.product_a_vpc.default_security_group_id]
  subnets            = [aws_subnet.sn_global_stg_1.id, aws_subnet.sn_global_stg_2.id]

  enable_deletion_protection = false
  depends_on = [
    aws_vpc.product_a_vpc
  ]
}

resource "aws_lb_listener" "product_a_alb_80" {
  load_balancer_arn = aws_alb.product_a_alb.arn
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


resource "aws_lb_target_group" "product_a_alb_target_group" {
  name                 = "productA-target-group"
  port                 = 80
  protocol             = "HTTP"
  protocol_version     = "GRPC"
  deregistration_delay = "300"
  proxy_protocol_v2    = false
  vpc_id               = aws_vpc.product_a_vpc.id
  target_type          = "ip"

  health_check {
    path                = "/com.example.grpc.health.Health/Check"
    healthy_threshold   = 5
    interval            = 30
    unhealthy_threshold = 2
    matcher             = "0"
    port                = "traffic-port"
    timeout             = 5
  }
}

resource "aws_lb_listener_rule" "product_a_alb_80_rule" {
  listener_arn = aws_lb_listener.product_a_alb_80.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product_a_alb_target_group.arn
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

resource "aws_alb" "product_a_internal_alb" {
  name               = "productA-internal"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id, aws_vpc.product_a_vpc.default_security_group_id]
  subnets            = [aws_subnet.sn_global_stg_1.id, aws_subnet.sn_global_stg_2.id]

  enable_deletion_protection = false
  depends_on = [
    aws_vpc.product_a_vpc
  ]
}

resource "aws_lb_listener" "product_a_internal_alb_80" {
  load_balancer_arn = aws_alb.product_a_internal_alb.arn
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

resource "aws_lb_listener_rule" "product_a_internal_alb_80_rule" {
  listener_arn = aws_lb_listener.product_a_internal_alb_80.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product_a_alb_target_group.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}
