terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Replace with your desired region
}

# Step 1: Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "production-vpc"
  }
}

# Step 2: Create Subnet
resource "aws_subnet" "prod-subnet" {
  vpc_id                  = aws_vpc.prod-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "production-subnet"
  }
}

# Step 3: Create Internet Gateway
resource "aws_internet_gateway" "prod-gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "production-gateway"
  }
}

# Step 4: Create Route Table
resource "aws_route_table" "prod_rt" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-gw.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.prod-gw.id
  }

  tags = {
    Name = "production-route-table"
  }
}

# Step 5: Associate Route Table with Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.prod-subnet.id
  route_table_id = aws_route_table.prod_rt.id
}

# Step 6: Create Security Group
resource "aws_security_group" "allow_web" {
  name        = "allow-web-traffic"
  description = "Allow SSH, HTTP, and HTTPS traffic"
  vpc_id      = aws_vpc.prod-vpc.id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-web-traffic"
  }
}

# Step 7: Create Network Interface
resource "aws_network_interface" "prod-nic" {
  subnet_id       = aws_subnet.prod-subnet.id
  private_ips     = ["10.0.1.10"]
  security_groups = [aws_security_group.allow_web.id]

  tags = {
    Name = "production-nic"
  }
}

# Step 8: Assign Elastic IP
resource "aws_eip" "prod-eip" {
  domain                       = "vpc"
  network_interface         = aws_network_interface.prod-nic.id
  associate_with_private_ip = "10.0.1.10"
  depends_on                = [aws_internet_gateway.prod-gw]

  tags = {
    Name = "production-eip"
  }
}

# Step 9: Create Ubuntu Server
resource "aws_instance" "web_server" {
  ami               = "ami-0b0ea68c435eb488d" # Replace with the latest Ubuntu AMI ID
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "main-key" # Replace with your key pair name

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.prod-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo systemctl enable apache2
              sudo echo "<h1>Welcome to PhineArt Terraform Project</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "production-server"
  }
}