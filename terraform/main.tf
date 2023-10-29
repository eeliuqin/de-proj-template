terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = var.aws_region
  profile = "default"
}

# Step 1 - Create security group for access to EC2 from your Anywhere

# Allows inbound (traffic to the EC2 instance) SSH connections on port 22 from any IP (0.0.0.0/0).
# Allows all outbound traffic.
# Allows outbound traffic on port 8080 for TCP protocol to any IP (0.0.0.0/0).
resource "aws_security_group" "sde_security_group" {
  name        = "sde_security_group"
  description = "Security group to allow inbound SCP & outbound 8080 (Airflow) connections"

  ingress {
    description = "Inbound SCP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sde_security_group"
  }
}

# Step 2 - Create EC2 with IAM role to allow EMR, Redshift, & S3 access and security group 
# The public key will be stored on the remote server (by us)
# The private key is kept securely on the user's local machine
# When a user attempts to log in to a remote server using SSH, the server checks the incoming public key against 
# the authorized keys in the user's account. 
# If a matching public key is found and the user possesses the corresponding private key, 
# access is granted without requiring a password. 

# Below resource will generate a private key as well as its associated public key (similar to ssh-gen)
# its value will be saved in a state file `./terraform/tfstate`
# After creating, we can access the private key: tls_private_key.custom_key.private_key_pem`
# access the public key: `tls_private_key.custom_key.public_key_openssh`
# but no worries, their values will be output as defined in output.tf
resource "tls_private_key" "custom_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# The public key that matched above private key will be saved in AWS
# key name in AWS: AWS will append a unique identifier to this prefix var.key_name to create the final key name
# key value: see above
resource "aws_key_pair" "generated_key" {
  key_name_prefix = var.key_name
  public_key      = tls_private_key.custom_key.public_key_openssh
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20220420"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Here only one EC2 instance will be created
# You can search how to set multiple instances, and ensure scalability

# AWS will assign a Public DNS to the EC2 instance
# To make the DNS available as an output, add it to output.tf
resource "aws_instance" "sde_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  key_name        = aws_key_pair.generated_key.key_name
  security_groups = [aws_security_group.sde_security_group.name]
  tags = {
    Name = "sde_ec2"
  }

  user_data = <<EOF
#!/bin/bash


# ------- Install docker and docker-compose in EC2, copy git repo to EC2, and run `make up` to spin up Airflow, Postgres containers -------

echo "-------------------------START SETUP---------------------------"
sudo apt-get -y update

sudo apt-get -y install \
ca-certificates \
curl \
gnupg \
lsb-release

sudo apt -y install unzip

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get -y update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo chmod 666 /var/run/docker.sock

sudo apt install make

echo 'Clone git repo to EC2'
cd /home/ubuntu && git clone ${var.repo_url}

echo 'CD to data_engineering_project_template directory'
cd data_engineering_project_template

echo 'Start containers & Run db migrations'
make up

echo "-------------------------END SETUP---------------------------"

EOF

}

# EC2 budget constraint
resource "aws_budgets_budget" "ec2" {
  name              = "budget-ec2-monthly"
  budget_type       = "COST"
  limit_amount      = "3"
  limit_unit        = "USD"
  time_period_end   = "2087-06-15_00:00"
  time_period_start = "2023-10-26_00:00"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email_id]
  }
}
