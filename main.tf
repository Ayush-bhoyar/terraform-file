provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "Main" {
  cidr_block = "10.0.0.0/16"
}

# Public Subnet 1
resource "aws_subnet" "public-1" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.Main.id
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

# Public Subnet 2
resource "aws_subnet" "public-2" {
  cidr_block              = "10.0.2.0/24"
  vpc_id                  = aws_vpc.Main.id
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
}

# Internet Gateway
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.Main.id
}

# Security Group
resource "aws_security_group" "web_sg" {
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.Main.id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-SG"
  }
}

# Route Table
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.Main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
}

# Route Table Associations
resource "aws_route_table_association" "RTA-1" {
  subnet_id      = aws_subnet.public-1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "RTA-2" {
  subnet_id      = aws_subnet.public-2.id
  route_table_id = aws_route_table.RT.id
}

# EC2 Instance 1
resource "aws_instance" "webserver-1" {
  instance_type               = "t2.micro"
  ami                         = "ami-04b4f1a9cf54c11d0"
  subnet_id                   = aws_subnet.public-1.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  key_name      = var.key_name 



  user_data = <<-EOF
              #!/bin/bash
              echo "Hello from Web Server 1" > /var/www/html/index.html
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              EOF
}

# EC2 Instance 2
resource "aws_instance" "webserver-2" {
  instance_type               = "t2.micro"
  ami                         = "ami-04b4f1a9cf54c11d0"
  subnet_id                   = aws_subnet.public-2.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  key_name      = var.key_name 

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello from Web Server 2" > /var/www/html/index.html
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              EOF
}

# Load Balancer
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]  # ✅ Correct syntax
  subnets            = [aws_subnet.public-1.id, aws_subnet.public-2.id]
}

# Target Group
resource "aws_lb_target_group" "TG" {
  name     = "ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.Main.id
}

# Load Balancer Listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.TG.arn
  }
}

# Attach Instances to Target Group
resource "aws_lb_target_group_attachment" "attach-1" {
  target_group_arn = aws_lb_target_group.TG.arn
  target_id        = aws_instance.webserver-1.id
  port            = 80
}

resource "aws_lb_target_group_attachment" "attach-2" {
  target_group_arn = aws_lb_target_group.TG.arn
  target_id        = aws_instance.webserver-2.id
  port            = 80
}
