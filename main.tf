provider "aws" {
  region = "ap-south-1"
}

variable "vpc_zone_identifier" {
  type        = list(string)
  description = "List of VPC subnet IDs"
  default     = ["subnet-09153db740467e15a", "subnet-01221c2705b0046bd", "subnet-01a2a1e8a4bea1176"] # Set your default subnet IDs here
}

resource "aws_ecs_cluster" "jenkins_cluster" {
  name = "jenkins-ecs-cluster"
}

resource "aws_launch_configuration" "jenkins_launch_configuration" {
  name                 = "jenkins-launch-config"
  image_id             = "ami-0aee0743bf2e81172" # Replace with your desired Jenkins-compatible AMI
  instance_type        = "t2.micro" # Replace with your desired instance type
  security_groups      = [aws_security_group.ecs_security_group.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.jenkins_cluster.name} >> /etc/ecs/ecs.config
              yum update -y
              yum install -y docker
              service docker start
              docker run -p 8080:8080 -p 50000:50000 jenkins/jenkins:lts
              EOF
}

resource "aws_autoscaling_group" "jenkins_autoscaling_group" {
  desired_capacity     = 1
  max_size             = 3
  min_size             = 1

  launch_configuration = aws_launch_configuration.jenkins_launch_configuration.id
  vpc_zone_identifier  = var.vpc_zone_identifier # Replace with your subnet ID
}

resource "aws_security_group" "ecs_security_group" {
  name        = "ecs-security-group"
  description = "Security group for ECS tasks"
  vpc_id      = "vpc-0405817222cfcf446" # Replace with your VPC ID

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
