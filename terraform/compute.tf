# CSYE 6225 - Assignment 6
# YOUR WORK: Complete this file.
#
# Define two aws_instance resources: "api" and "worker". This is the
# reverse of Assignment 5 - there, compute.tf was provided and you wrote
# the network. Here, the network (network.tf, subnets.tf,
# security_groups.tf, nacls.tf) is provided complete, and you write the
# compute layer, based on the instance types YOU choose in
# terraform.tfvars.
#
# --- Picking the right AMI for your chosen instance type ---
#
# ami.tf (provided) gives you two AMI lookups:
#   data.aws_ssm_parameter.ubuntu_amd64.value  - for x86_64 instance types
#   data.aws_ssm_parameter.ubuntu_arm64.value  - for Graviton/ARM instance types
#
# How to tell which one you need: Graviton/ARM instance type names end
# in "g" (e.g., t4g, c6g, c7g, m6g). Everything else (t3, c5, c6i, m5,
# etc.) is x86_64. Pick the AMI that matches the architecture of the
# instance type you chose for each host - an architecture mismatch will
# fail to boot.
#
# --- Resource "api" requirements ---
#   - ami: matching var.api_instance_type's architecture
#   - instance_type: var.api_instance_type
#   - key_name: var.key_name
#   - subnet_id: the public subnet (from subnets.tf)
#   - vpc_security_group_ids: [aws_security_group.api_sg.id]
#   - associate_public_ip_address: true
#   - user_data: templatefile("${path.module}/scripts/user_data.sh.tpl", {
#       app_server_py = file("${path.module}/../app/server.py")
#       host_role     = "api"
#     })
#   - tags: at minimum Name = "assignment6-api"
#
# --- Resource "worker" requirements ---
#   - ami: matching var.worker_instance_type's architecture
#   - instance_type: var.worker_instance_type
#   - key_name: var.key_name
#   - subnet_id: the private subnet (from subnets.tf)
#   - vpc_security_group_ids: [aws_security_group.worker_sg.id]
#   - associate_public_ip_address: false
#   - user_data: same templatefile pattern, with host_role = "worker"
#   - tags: at minimum Name = "assignment6-worker"
#
# Resource names outputs.tf expects from this file:
#   aws_instance.api
#   aws_instance.worker

# --- Host A: public API tier ---
# t4g.micro is Graviton (arm64), so it uses the arm64 AMI.
resource "aws_instance" "api" {
  ami                         = data.aws_ssm_parameter.ubuntu_arm64.value
  instance_type               = var.api_instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.api_sg.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/scripts/user_data.sh.tpl", {
    app_server_py = file("${path.module}/../app/server.py")
    host_role     = "api"
  })

  tags = {
    Name = "assignment6-api"
  }
}

# --- Host B: private batch worker ---
# c6i.large is Intel (x86_64; the "i" is Intel, not Graviton), so it uses the amd64 AMI.
resource "aws_instance" "worker" {
  ami                         = data.aws_ssm_parameter.ubuntu_amd64.value
  instance_type               = var.worker_instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.worker_sg.id]
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/scripts/user_data.sh.tpl", {
    app_server_py = file("${path.module}/../app/server.py")
    host_role     = "worker"
  })

  tags = {
    Name = "assignment6-worker"
  }
}
