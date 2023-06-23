resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "aurora-subnet-group"
  subnet_ids = [
    data.terraform_remote_state.product_b.outputs.sn_private_1_id,
    data.terraform_remote_state.product_b.outputs.sn_private_2_id,
    data.terraform_remote_state.product_b.outputs.sn_private_3_id
  ]

  tags = {
    Name: "aurora-subnet-group"
  }
}
