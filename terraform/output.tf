output "aws_region" {
  description = "Region set for AWS"
  value       = var.aws_region
}

# in main.tf, after creating ec2 instance, attributes like public_dns of that instance's is accessiable
# output has 2 features: 1) output to the terminal 2) saved in Terraform State, so later we can retrive it again using the `terraform output` command
output "ec2_public_dns" {
  description = "EC2 public dns."
  value       = aws_instance.sde_ec2.public_dns
}

output "public_key" {
  description = "EC2 public key."
  value       = tls_private_key.custom_key.public_key_openssh
}
