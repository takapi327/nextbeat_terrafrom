// ---------- [ Global Subnet ] -------------------------------
resource "aws_subnet" "sn_global_1" {
  cidr_block              = var.platform_subnet_ips.a_global
  vpc_id                  = aws_vpc.platform_vpc.id
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false

  tags = {
    Name : "sn-global-1"
  }
}

resource "aws_subnet" "sn_global_2" {
  cidr_block              = var.platform_subnet_ips.b_global
  vpc_id                  = aws_vpc.platform_vpc.id
  availability_zone       = "ap-northeast-1d"
  map_public_ip_on_launch = false

  tags = {
    Name : "sn-global-2"
  }
}

resource "aws_subnet" "sn_global_3" {
  cidr_block              = var.platform_subnet_ips.c_global
  vpc_id                  = aws_vpc.platform_vpc.id
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false

  tags = {
    Name : "sn-global-3"
  }
}

// ---------- [ Private Subnet ] -------------------------------
resource "aws_subnet" "sn_private_1" {
  cidr_block              = var.platform_subnet_ips.a_private
  vpc_id                  = aws_vpc.platform_vpc.id
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false

  tags = {
    Name : "sn-private-1"
  }
}

resource "aws_subnet" "sn_private_2" {
  cidr_block              = var.platform_subnet_ips.b_private
  vpc_id                  = aws_vpc.platform_vpc.id
  availability_zone       = "ap-northeast-1d"
  map_public_ip_on_launch = false

  tags = {
    Name : "sn-private-2"
  }
}

resource "aws_subnet" "sn_private_3" {
  cidr_block              = var.platform_subnet_ips.c_private
  vpc_id                  = aws_vpc.platform_vpc.id
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false

  tags = {
    Name : "sn-private-3"
  }
}
