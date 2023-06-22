resource "aws_eip" "eip" {}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = data.terraform_remote_state.product_b.outputs.sn_global_1_id

  tags = {
    Name : "ngw-productB"
  }
}
