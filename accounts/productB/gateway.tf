resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.product_b_vpc.id
  tags = {
    Name : "igw-productB"
  }
}

resource "aws_eip" "eip" {}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.sn_global_1.id

  tags = {
    Name : "ngw-productB"
  }
}
