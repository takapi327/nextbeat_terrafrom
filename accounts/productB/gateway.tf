resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.product_b_vpc.id
  tags = {
    Name : "igw-productB"
  }
}
