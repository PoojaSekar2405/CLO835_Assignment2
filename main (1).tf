provider "aws" {
  region = "us-east-1"
}

# Retrieve the default VPC
data "aws_vpc" "default_vpc" {
  default = true
}

# Retrieve the default subnet in a specific availability zone
data "aws_subnet" "primary_subnet" {
  availability_zone = "us-east-1a"

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

# Define Security Group with SSH and HTTP Access
resource "aws_security_group" "web_access" {
  name        = "web-sec-group"
  description = "Allow SSH and HTTP access"
  vpc_id      = data.aws_vpc.default_vpc.id

  # Allow SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create EC2 Instance for Web Application
resource "aws_instance" "app_server" {
  ami                         = "ami-0c614dee691cbbf37"
  instance_type               = "t2.medium"
  subnet_id                   = data.aws_subnet.primary_subnet.id
  vpc_security_group_ids      = [aws_security_group.web_access.id]
  associate_public_ip_address = true  # Keep this for initial assignment
  key_name                    = "vockey" # Ensure you have this key pair

  # Specify root volume size (20GB)
  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Update the system
              sudo yum update -y

              # Install Docker
              sudo yum install -y docker
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ec2-user

              # Install kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

              # Install kind
              curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
              chmod +x ./kind
              sudo mv ./kind /usr/local/bin/kind

              # Reboot to apply Docker group changes
              sudo reboot
              EOF

  tags = {
    Name    = "WebApp-Instance"
    Project = "Deployment-Task"
  }
}

# Allocate an Elastic IP (EIP) for the EC2 Instance
resource "aws_eip" "web_eip" {
  domain = "vpc"
  tags = {
    Name = "WebApp-EIP"
  }
}

# Associate the Elastic IP with the EC2 Instance
resource "aws_eip_association" "web_eip_assoc" {
  instance_id   = aws_instance.app_server.id
  allocation_id = aws_eip.web_eip.id
}

# Create ECR Repository for Web Application
resource "aws_ecr_repository" "web_repository" {
  name = "webapp-assignment2"

  tags = {
    Project   = "Deployment-Task"
    Component = "Web Application"
  }
}

# Create ECR Repository for Database
resource "aws_ecr_repository" "db_repository" {
  name = "database-assignment2"

  tags = {
    Project   = "Deployment-Task"
    Component = "Database"
  }
}
