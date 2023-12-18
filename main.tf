provider "aws" {
  region = "ap-south-1"  # Replace with your AWS region
}

# Create a VPC as per our given CIDR block
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "VPC_Pro2"
  }
}


resource "aws_subnet" "ecs_subnet" {
  vpc_id     = aws_vpc.my_vpc.id  # Replace with your VPC ID where you want to create the subnet
  cidr_block = "10.0.1.0/24"  # Define the CIDR block for your new subnet

  # Add any additional configuration as needed for your subnet
  # For example, availability_zone, tags, etc.
}

resource "aws_security_group" "ecs_security_group" {
  name        = "ecs-security-group"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.my_vpc.id  # Associate the security group with the VPC
  
  # Define your security group rules here
  # Example inbound rules (modify as needed)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Adjust CIDR block for your network
  }

  # Example outbound rules (modify as needed)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Adjust CIDR block for your network
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


resource "aws_ecs_cluster" "python_cluster" {
  name = "python-ecs-cluster"
}

resource "aws_launch_configuration" "ecs_launch_configuration" {
  name                 = "ecs-launch-config"
  image_id             = "ami-0aee0743bf2e81172"  # Replace with your AMI ID
  instance_type        = "t2.small"  # Choose instance type as per your requirements
  associate_public_ip_address = true
  subnets = [aws_subnet.ecs_subnet.id]  # Replace with your subnet ID
  security_groups = [aws_security_group.ecs_security_group.id]  # Reference the created security group
  }

  # Other configurations for the launch configuration as needed
  # For instance, security_groups, key_name, user_data, etc.
}

resource "aws_autoscaling_group" "ecs_autoscaling_group" {
  desired_capacity     = 1  # Number of instances to launch initially
  max_size             = 3  # Maximum number of instances in the group
  min_size             = 1  # Minimum number of instances in the group

  launch_configuration = aws_launch_configuration.ecs_launch_configuration.id
  vpc_zone_identifier  = [aws_subnet.ecs_subnet.id]  # Subnet IDs where instances will be launched
}

resource "aws_ecs_task_definition" "python_task_definition" {
  family                   = "python-task-family"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]  # Use EC2 launch type

  cpu    = "512"   # 0.5 vCPU
  memory = "1024"  # 1GB

  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "python-container"
      image = "amazonlinux:latest"
      cpu   = 512
      memory = 1024
      essential = true
      command = [
        "/bin/bash",
        "-c",
        "yum update -y && yum install -y python3.6"# Replace with your Python script
      ]
    }
  ])
}

resource "aws_ecs_service" "python_ecs_service" {
  name            = "python-ecs-service"
  cluster         = aws_ecs_cluster.python_cluster.id
  task_definition = aws_ecs_task_definition.python_task_definition.arn
  launch_type     = "EC2"

  network_configuration {
    subnets = [aws_subnet.ecs_subnet.id]  # Replace with your subnet ID
    security_groups = [aws_security_group.ecs_security_group.id]  # Reference the created security group
  }
  deployment_controller {
    type = "ECS"
  }
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_ecs_task_definition.python_task_definition]
}
