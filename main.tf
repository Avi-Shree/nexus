terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.64.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

#generate key pair

resource "tls_private_key" "nexus" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "nexus" {
  content  = tls_private_key.nexus.private_key_pem
  filename = "${path.module}/nexus.pem"
}

resource "aws_key_pair" "nexus" {
  key_name   = "deployer-key"
  public_key = tls_private_key.nexus.public_key_openssh
}

# Create VPC
resource "aws_vpc" "nexus" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "nexus"
  }
}

# Create Public Subnet
resource "aws_subnet" "nexus-public" {
  vpc_id            = aws_vpc.nexus.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "nexus-PublicSubnet"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "nexus-igw" {
  vpc_id = aws_vpc.nexus.id
  
  tags = {
    Name = "nexusInternetGateway"
  }
}

# Create Route Table for Public Subnet
resource "aws_route_table" "nexus-public" {
  vpc_id = aws_vpc.nexus.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nexus-igw.id
  }
  
  tags = {
    Name = "nexus-PublicRouteTable"
  }
}

# Associate Public Route Table with Public Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.nexus-public.id
  route_table_id = aws_route_table.nexus-public.id
}


# Create Security Group for EC2 instance
resource "aws_security_group" "nexus_sg" {
  name        = "nexus-sg"
  description = "Security group for Nexus instance"
  vpc_id      = aws_vpc.nexus.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8070
    to_port     = 8070
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nexus-sg"
  }
}

# Create an EC2 instance
resource "aws_instance" "nexus_instance" {
  ami                    = "ami-0522ab6e1ddcc7055"
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.nexus.key_name
  subnet_id              = aws_subnet.nexus-public.id
  vpc_security_group_ids = [aws_security_group.nexus_sg.id]

  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.tpl", {})

  tags = {
    Name = "Nexus-Instance"
  }
}