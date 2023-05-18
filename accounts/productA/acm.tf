resource "aws_acm_certificate" "product_a_acm" {
  domain_name = "*.product.a.service"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "productA-acm"
  }
}
