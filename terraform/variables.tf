# CSYE 6225 - Assignment 6
# Provided complete. Do not modify.

variable "key_name" {
  description = "Name of your own EC2 key pair, used for SSH access to the API host"
  type        = string
}

variable "api_instance_type" {
  description = "EC2 instance type for the API host - YOUR choice, based on the workload spec in the assignment"
  type        = string
}

variable "worker_instance_type" {
  description = "EC2 instance type for the worker host - YOUR choice, based on the workload spec in the assignment"
  type        = string
}
