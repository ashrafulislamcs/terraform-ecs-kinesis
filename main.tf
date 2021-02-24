provider "aws" {
  region = var.region
}

data "aws_iam_role" "ecr" {
  name = "AWSServiceRoleForECRReplication"
}

module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=master"
  namespace  = "everlook"
  stage      = "dev"
  name       = "kinesis"
  attributes = ["public"]
  delimiter  = "-"
}

resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "public_az1" {
  availability_zone       = "us-east-1a"
  cidr_block              = "10.10.10.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = {
    Name = "Public subnet for us-east-1a"
  }
}

resource "aws_subnet" "private_az1" {
  availability_zone       = "us-east-1b"
  cidr_block              = "10.10.20.0/24"
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.main.id

  tags = {
    Name = "Private subnet for us-east-1a"
  }
}

resource "aws_eip" "nat1" {
  vpc = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_nat_gateway" "private" {
  allocation_id = aws_eip.nat1.id
  subnet_id     = aws_subnet.public_az1.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private.id
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_az1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public.id
}

module "ecr" {
  source                 = "git::https://github.com/cloudposse/terraform-aws-ecr.git?ref=master"
  namespace              = module.label.namespace
  stage                  = module.label.stage
  name                   = module.label.name
  principals_full_access = [data.aws_iam_role.ecr.arn]
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

resource "aws_cloudwatch_log_group" "node-ecs" {
  name = "node-ecs"
}

resource "aws_ecs_task_definition" "node" {
  family                   = "node-ecs"
  network_mode             = var.network_mode
  requires_compatibilities = [var.ecs_launch_type]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn

  container_definitions    = <<DEFINITION
[
  {
    "cpu": ${var.task_cpu},
    "environment": [{
      "name": "DEBUG",
      "value": "api*"
    }],
    "essential": true,
    "image": "${module.ecr.repository_url}:latest",
    "memory": ${var.task_memory},
    "name": "node-ecs",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "${var.region}",
        "awslogs-group": "${aws_cloudwatch_log_group.node-ecs.id}",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
DEFINITION
}

resource "aws_ecs_cluster" "default" {
  name = module.label.id
}

resource "aws_security_group" "ecs" {
  name        = "ECS service sec group"
  description = "Private cluster security group"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Private egress Sec Group"
  }
}

resource "aws_ecs_service" "node" {
  name                               = module.label.name
  cluster                            = aws_ecs_cluster.default.id
  task_definition                    = aws_ecs_task_definition.node.arn
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent 
  desired_count                      = 2
  launch_type                        = var.ecs_launch_type

  network_configuration {
    subnets          = [aws_subnet.private_az1.id]
    security_groups  = [aws_security_group.ecs.id]
  }
}

resource "aws_kinesis_stream" "test" {
  name             = "test"
  shard_count      = 3
  retention_period = 24

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]

  tags = {
    Environment = "dev"
  }
}