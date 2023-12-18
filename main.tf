provider "aws" {
  region = "ap-south-1"  # Replace with your AWS region
}

resource "aws_subnet" "ecs_subnet" {
  vpc_id     = vpc-04fab404a15b881ae  # Replace with your VPC ID where you want to create the subnet
  cidr_block = "10.0.1.0/24"  # Define the CIDR block for your new subnet

  # Add any additional configuration as needed for your subnet
  # For example, availability_zone, tags, etc.
}

resource "aws_security_group" "ecs_security_group" {
  name        = "ecs-security-group"
  description = "Security group for ECS tasks"
  
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

  # Example policy for ECS execution role (modify as needed)
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  # Define IAM role policies, permissions, etc. for ECS tasks
  # ...

  # Example policy for ECS task role (modify as needed)
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_ecs_cluster" "python_cluster" {
  name = "python-ecs-cluster"
}

resource "aws_ecs_task_definition" "python_task_definition" {
  family                   = "python-task-family"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

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
        "sudo apt-get update",
	"sudo apt-get install python3.6"# Replace with your Python script
      ]
    }
  ])
}

resource "aws_ecs_service" "python_ecs_service" {
  name            = "python-ecs-service"
  cluster         = aws_ecs_cluster.python_cluster.id
  task_definition = aws_ecs_task_definition.python_task_definition.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets = ["subnet-0b9673721a5f76656"]  # Replace with your subnet ID
    security_groups = [aws_security_group.ecs_security_group.id]  # Reference the created security group
  }

  depends_on = [aws_ecs_task_definition.python_task_definition]
}
