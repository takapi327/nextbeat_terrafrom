resource "aws_instance" "bastion" {
  ami                     = "ami-0521a4a0a1329ff86"
  instance_type           = "t3.nano"
  subnet_id               = aws_subnet.sn_private_1.id
  vpc_security_group_ids  = [aws_security_group.bastion.id]
  iam_instance_profile    = "EC2BastionRole"

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = "1"
    http_tokens                 = "required"
  }

  tags = {
    Name = "ec2-bastion"
  }
}
