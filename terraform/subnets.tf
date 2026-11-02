resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.20.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "assignment6-public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.20.2.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "assignment6-private-subnet"
  }
}
