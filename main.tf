provider "aws" {
  region = "ap-southeast-1" # change as needed
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "sonar_sg" {
  name        = "sonar-sg"
  description = "Allow SSH and SonarQube"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Optional: Sonar sometimes uses 8080 in reverse proxy setups
  ingress {
    from_port   = 8080
    to_port     = 8080
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
    Name = "sonar-sg"
  }
}

resource "aws_instance" "sonar_ec2" {
  ami                    = "ami-0df7a207adb9748c7" # Ubuntu 22.04 (update if needed)
  instance_type          = "c7i-flex.large"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.sonar_sg.id]
  key_name               = "ssh-2" # replace with your keypair

  tags = {
    Name = "SonarQube-EC2"
  }
}

# ---------------- S3 Bucket ----------------
resource "aws_s3_bucket" "sonar_bucket" {
  bucket = "neuroninja-shubham-terraform-bucket31" # must be globally unique name
  force_destroy = true
  tags = {
    Name        = "sonar-artifacts"
    Environment = "Dev"
  }
}

# (Optional) Enable versioning
resource "aws_s3_bucket_versioning" "sonar_bucket_versioning" {
  bucket = aws_s3_bucket.sonar_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------- Outputs ----------------
output "ec2_public_ip" {
  value = aws_instance.sonar_ec2.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.sonar_bucket.bucket
}
