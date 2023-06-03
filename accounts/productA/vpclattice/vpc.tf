data "aws_network_interface" "product_a_internal_nlb_network_interface" {
  filter {
    name   = "description"
    values = ["ELB ${aws_alb.product_a_internal_nlb.arn_suffix}"]
  }

  filter {
    name   = "subnet-id"
    values = [
      data.terraform_remote_state.product_a.outputs.sn_private_1_id,
      data.terraform_remote_state.product_a.outputs.sn_private_1_id
    ]
  }
}
