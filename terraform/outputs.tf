# CSYE 6225 - Assignment 6
# Provided complete. Do not modify.
#
# Gradescope reads these values directly from your committed
# terraform.tfstate to run its live checks. They're also useful to you:
# run `terraform output` after apply to see a quick summary of what you
# actually deployed, without digging through the AWS Console.
#
# api_ami_id and worker_ami_id are marked sensitive = true: the AWS
# provider flags all SSM parameter values as potentially sensitive, so
# Terraform requires outputs built from them to opt in explicitly. This
# means `terraform plan`/`terraform output` will print these two as
# <sensitive> rather than the literal AMI ID - run
# `terraform output -raw api_ami_id` (or -json) if you need to see it.

output "api_public_ip" {
  description = "Public IP address of the API host"
  value       = aws_instance.api.public_ip
}

output "worker_private_ip" {
  description = "Private IP address of the worker host"
  value       = aws_instance.worker.private_ip
}

output "api_instance_type" {
  description = "EC2 instance type chosen for the API host"
  value       = aws_instance.api.instance_type
}

output "worker_instance_type" {
  description = "EC2 instance type chosen for the worker host"
  value       = aws_instance.worker.instance_type
}

output "api_ami_id" {
  description = "AMI ID used for the API host"
  value       = aws_instance.api.ami
  sensitive   = true
}

output "worker_ami_id" {
  description = "AMI ID used for the worker host"
  value       = aws_instance.worker.ami
  sensitive   = true
}
