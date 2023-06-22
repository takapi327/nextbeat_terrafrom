// ---------- [ Global Route Table ] -------------------------------
resource "aws_route_table" "rtb_global" {
  vpc_id = aws_vpc.product_b_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name : "rtb-global"
  }
}

resource "aws_route_table_association" "global_1" {
  route_table_id = aws_route_table.rtb_global.id
  subnet_id      = aws_subnet.sn_global_1.id
}

resource "aws_route_table_association" "global_2" {
  route_table_id = aws_route_table.rtb_global.id
  subnet_id      = aws_subnet.sn_global_2.id
}

resource "aws_route_table_association" "global_3" {
  route_table_id = aws_route_table.rtb_global.id
  subnet_id      = aws_subnet.sn_global_3.id
}
