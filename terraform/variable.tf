## AWS account level config: region
## For EC2, N.Virginia (us-east-1) seems the most economic
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

## Key to allow connection to our EC2 instance
variable "key_name" {
  description = "EC2 key name"
  type        = string
  default     = "sde-key"
}

## EC2 instance type
variable "instance_type" {
  description = "Instance type for EMR and EC2"
  type        = string
  default     = "t2.medium"
}

## Alert email receiver
variable "alert_email_id" {
  description = "Email id to send alerts to "
  type        = string
  default     = "qinliu.utd@gmail.com"
}

## Your repository url
# Terraform's main.tf will clone this repo to EC2
variable "repo_url" {
  description = "Repository url to clone into production machine"
  type        = string
  default     = "https://github.com/eeliuqin/de-proj-template.git"
}
