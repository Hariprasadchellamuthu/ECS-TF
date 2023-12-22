provider "aws" {
  region = "ap-south-1"
}

variable "vpc_zone_identifier" {
  type        = list(string)
  description = "List of VPC subnet IDs"
  default     = ["subnet-09153db740467e15a", "subnet-01221c2705b0046bd", "subnet-01a2a1e8a4bea1176"] # Set your default subnet IDs here
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

resource "aws_iam_role" "ecs_execution_role" {
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name   = "ecs_execution_role_policy"
  role   = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:CreateTags",
          "ec2:RunInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:TerminateInstances",
          # Add other EC2 related actions as necessary
        ],
        Resource = "*",
      },
    ],
  })
}


resource "aws_iam_role" "ecs_task_role" {
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name   = "ecs_task_role_policy"
  role   = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "iam:PassRole",
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:DeleteRole",
          # Add other IAM related actions as necessary
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          # Add other security group related actions as necessary
        ],
        Resource = "*",
      },
    ],
  })
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
              systemctl start docker
              systemctl enable docker
              EOF
}

resource "aws_autoscaling_group" "jenkins_autoscaling_group" {
  desired_capacity     = 1
  max_size             = 3
  min_size             = 1

  launch_configuration = aws_launch_configuration.jenkins_launch_configuration.id
  vpc_zone_identifier  = var.vpc_zone_identifier # Replace with your subnet ID

  health_check_type          = "EC2"
  health_check_grace_period  = 300
  force_delete               = true
}

# ECS Task Definition for Jenkins
resource "aws_ecs_task_definition" "jenkins_task_definition" {
  family                   = "jenkins-task-family"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]

  cpu    = "512"
  memory = "1024"

  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "jenkins-container"
      image = "jenkins/jenkins:lts"
      cpu   = 512
      memory = 1024
      essential = true
      portMappings = [
        {
          containerPort = 8080,
          hostPort      = 8080
        },
      ]
    }
  ])
}

# ECS Service for Jenkins
resource "aws_ecs_service" "jenkins_ecs_service" {
  name            = "jenkins-ecs-service"
  cluster         = aws_ecs_cluster.jenkins_cluster.id
  task_definition = aws_ecs_task_definition.jenkins_task_definition.arn
  launch_type     = "EC2"

  network_configuration {
    subnets         = [aws_subnet.subnet_a.id]
    security_groups = [aws_security_group.ecs_security_group.id]
  }

  deployment_controller {
    type = "ECS"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_ecs_task_definition.jenkins_task_definition]
}


