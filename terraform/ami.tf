# CSYE 6225 - Assignment 6
# Provided complete. Do not modify.
#
# Looks up the latest Ubuntu 22.04 LTS AMI for BOTH x86_64 and arm64
# architectures, using the same AWS Systems Manager (SSM) parameter
# technique covered in the Module 6 CLI walkthrough:
#
#   aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id
#
# Note: this uses the "ebs-gp2" volume-type path, not "ebs-gp3". Canonical
# only publishes ebs-gp3 parameters for Ubuntu 23.10 and later - 22.04
# (used throughout this course) only has an ebs-gp2 parameter. If you ever
# port this pattern to a newer Ubuntu release, check which volume type its
# SSM path actually publishes before copying this verbatim.
#
# Reference these in compute.tf based on the instance type you choose:
#   - If your instance type is Graviton/ARM (family ends in "g", e.g.
#     t4g, c6g, c7g, m6g), use data.aws_ssm_parameter.ubuntu_arm64.value
#   - Otherwise (x86_64 families, e.g. t3, c5, c6i, m5), use
#     data.aws_ssm_parameter.ubuntu_amd64.value

data "aws_ssm_parameter" "ubuntu_amd64" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

data "aws_ssm_parameter" "ubuntu_arm64" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/arm64/hvm/ebs-gp2/ami-id"
}
