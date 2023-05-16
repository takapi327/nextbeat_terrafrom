resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.product_a_vpc.id
  tags = {
    Name : "igw-productA"
  }
}

resource "aws_eip" "eip" {}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.sn_global_stg_1.id

  tags = {
    Name : "ngw-productA"
  }
}
