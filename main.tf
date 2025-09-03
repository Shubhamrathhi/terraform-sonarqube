provider "aws" {
  region = "ap-southeast-1"
}

# -----------------
# VPC + Networking
# -----------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1a"
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1a"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# -----------------
# Security Groups
# -----------------
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "jenkins_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Jenkins Web UI
  }

  ingress {
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
}

resource "aws_security_group" "sonarqube_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_sg.id] # only Jenkins can access SonarQube
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # SSH via Bastion
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------
# EC2 Instances
# -----------------
resource "aws_instance" "bastion" {
  ami           = "ami-0f62d9254ca98e1aa" # Ubuntu 22.04 (example)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = "my-key"

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  tags = {
    Name = "BastionHost"
  }
}

resource "aws_instance" "jenkins" {
  ami           = "ami-0f62d9254ca98e1aa"
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.public.id
  key_name      = "my-key"

  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  tags = {
    Name = "JenkinsServer"
  }
}

resource "aws_instance" "sonarqube" {
  ami           = "ami-0f62d9254ca98e1aa"
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.private.id
  key_name      = "my-key"

  vpc_security_group_ids = [aws_security_group.sonarqube_sg.id]
  tags = {
    Name = "SonarQubeServer"
  }
}

# -----------------
# Outputs
# -----------------
output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}

output "jenkins_ip" {
  value = aws_instance.jenkins.public_ip
}

output "sonarqube_private_ip" {
  value = aws_instance.sonarqube.private_ip
}
