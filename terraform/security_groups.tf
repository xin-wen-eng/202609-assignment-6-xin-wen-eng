# CSYE 6225 - Assignment 6
# Provided complete. Do not modify.
#
# This is the same Security Group design pattern from Assignment 5,
# renamed for this assignment's two hosts: api_sg (public tier) and
# worker_sg (private tier).

resource "aws_security_group" "api_sg" {
  name        = "assignment6-api-sg"
  description = "Allow SSH and HTTP from the internet; allow outbound to the worker subnet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress uses the private subnet's CIDR, not a direct reference to
  # worker_sg - referencing worker_sg here would create a circular
  # dependency, since worker_sg's ingress rule references api_sg.
  egress {
    description = "SSH to worker subnet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.20.2.0/24"]
  }

  egress {
    description = "HTTP to worker subnet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["172.20.2.0/24"]
  }

  tags = {
    Name = "assignment6-api-sg"
  }
}

resource "aws_security_group" "worker_sg" {
  name        = "assignment6-worker-sg"
  description = "Allow SSH and HTTP only from the api security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from api host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.api_sg.id]
  }

  ingress {
    description     = "HTTP from api host"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.api_sg.id]
  }

  # No egress rules: this instance never initiates outbound connections,
  # and Security Groups are stateful, so replies to the inbound
  # SSH/HTTP requests above don't need a matching egress rule.

  tags = {
    Name = "assignment6-worker-sg"
  }
}
