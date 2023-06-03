// ---------- [ Global Route Table ] -------------------------------
resource "aws_route_table" "rtb_global" {
  vpc_id = aws_vpc.product_a_vpc.id

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

// ---------- [ Private Route Table ] -------------------------------
resource "aws_route_table" "rtb_private" {
  vpc_id = aws_vpc.product_a_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name : "rtb-private"
  }
}

resource "aws_route_table_association" "private_1" {
  route_table_id = aws_route_table.rtb_private.id
  subnet_id      = aws_subnet.sn_private_1.id
}

resource "aws_route_table_association" "private_2" {
  route_table_id = aws_route_table.rtb_private.id
  subnet_id      = aws_subnet.sn_private_2.id
}

resource "aws_route_table_association" "private_3" {
  route_table_id = aws_route_table.rtb_private.id
  subnet_id      = aws_subnet.sn_private_3.id
}
