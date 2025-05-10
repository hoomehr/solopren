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

# --- VPC Configuration ---
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a" #Replace with your AZ
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1a"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b" #Replace with your AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1b"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# --- Security Group ---
resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #Restrict this to your network
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #Restrict this to your network
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #Restrict this to your network
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-security-group"
  }
}

# --- Launch Template ---
resource "aws_launch_template" "app_launch_template" {
  name_prefix   = "app-launch-template-"
  image_id      = "ami-0c55b17bb8554a982" # Replace with your desired AMI
  instance_type = "t3.medium"
  key_name      = "your-key-pair"  # Replace with your key pair name
  security_group_names = [aws_security_group.app_sg.name]

  user_data = base64encode(<<EOF
#!/bin/bash
echo "Hello, World from Terraform!" > /tmp/hello.txt
# Add your deployment script here to install Node.js, MongoDB client, and clone/start the application
# Example:
# yum update -y
# yum install -y nodejs npm
# git clone <your_git_repo> /var/www/app
# cd /var/www/app
# npm install
# npm start
EOF
  )

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-instance"
    }
  }
}

# --- Auto Scaling Group ---
resource "aws_autoscaling_group" "app_asg" {
  name                 = "app-asg"
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  launch_template {
    id      = aws_launch_template.app_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }
}

# --- Application Load Balancer ---
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "application-load-balancer"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path     = "/" # Replace with your application's health check path
    protocol = "HTTP"
    matcher  = "200-399"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.app_asg.id
  lb_target_group_arn    = aws_lb_target_group.app_tg.arn
}

# --- Route 53 (Optional - if you have a domain) ---
# data "aws_route53_zone" "selected" {
#   name         = "yourdomain.com"  # Replace with your domain name
#   private_zone = false
# }

# resource "aws_route53_record" "www" {
#   zone_id = data.aws_route53_zone.selected.zone_id
#   name    = "www.yourdomain.com"  # Replace with your desired subdomain
#   type    = "A"
#   ttl     = "300"
#   records = [aws_lb.app_lb.dns_name]
# }

# --- CloudWatch Alarm (Example) ---
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "Alarm when server CPU exceeds 70%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }

  alarm_actions = [aws_autoscaling_group.app_asg.id]
}