// ---------- [ Global Subnet ] -------------------------------
resource "aws_subnet" "sn_global_stg_1" {
  cidr_block              = var.product_a_subnet_ips.a_global
  vpc_id                  = aws_vpc.product_a_vpc.id
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false

  tags = {
    Name : "sn-global-stg-1"
  }
}

resource "aws_subnet" "sn_global_stg_2" {
  cidr_block              = var.product_a_subnet_ips.b_global
  vpc_id                  = aws_vpc.product_a_vpc.id
  availability_zone       = "ap-northeast-1d"
  map_public_ip_on_launch = false

  tags = {
    Name : "sn-global-stg-2"
  }
}

resource "aws_subnet" "sn_global_stg_3" {
  cidr_block              = var.product_a_subnet_ips.c_global
  vpc_id                  = aws_vpc.product_a_vpc.id
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false

  tags = {
    Name : "sn-global-stg-3"
  }
}

// ---------- [ Private Subnet ] -------------------------------
resource "aws_subnet" "sn_private_stg_1" {
  cidr_block              = var.product_a_subnet_ips.a_private
  vpc_id                  = aws_vpc.product_a_vpc.id
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false

  tags = {
    Name : "sn-private-stg-1"
  }
}

resource "aws_subnet" "sn_private_stg_2" {
  cidr_block              = var.product_a_subnet_ips.b_private
  vpc_id                  = aws_vpc.product_a_vpc.id
  availability_zone       = "ap-northeast-1d"
  map_public_ip_on_launch = false

  tags = {
    Name : "sn-private-stg-2"
  }
}

resource "aws_subnet" "sn_private_stg_3" {
  cidr_block              = var.product_a_subnet_ips.c_private
  vpc_id                  = aws_vpc.product_a_vpc.id
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false

  tags = {
    Name : "sn-private-stg-3"
  }
}
