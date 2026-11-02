# A custom NACL on the private subnet only. The public subnet stays on
# its default NACL (which allows all traffic).

resource "aws_network_acl" "private_nacl" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private.id]

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "172.20.1.0/24"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "172.20.1.0/24"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "172.20.1.0/24"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "172.20.1.0/24"
    from_port  = 1024
    to_port    = 65535
  }

  # No route to 0.0.0.0/0 is needed or expected in either direction -
  # the private host never talks to the internet.

  tags = {
    Name = "assignment6-private-nacl"
  }
}
