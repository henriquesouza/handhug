terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  s3_use_path_style           = true

  endpoints {
    ec2         = "http://localhost:4566"
    elasticache = "http://localhost:4566"
    mq          = "http://localhost:4566"
  }
}

# ============================================
# VPC
# ============================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "floci-vpc"
  }
}

# ============================================
# SUBNETS
# ============================================
resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "floci-subnet-a"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "floci-subnet-b"
  }
}

# ============================================
# INTERNET GATEWAY
# ============================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "floci-igw"
  }
}

# ============================================
# ROUTE TABLE
# ============================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "floci-rt-public"
  }
}

resource "aws_route_table_association" "subnet_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "subnet_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public.id
}

# ============================================
# SECURITY GROUP (Redis)
# ============================================
resource "aws_security_group" "redis" {
  name        = "floci-redis-sg"
  description = "Security Group para Redis no Floci"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Redis"
    from_port   = 6379
    to_port     = 6379
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
    Name = "floci-redis-sg"
  }
}

# ============================================
# SECURITY GROUP (RabbitMQ)
# ============================================
resource "aws_security_group" "rabbitmq" {
  name        = "floci-rabbitmq-sg"
  description = "Security Group para RabbitMQ no Floci"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "AMQP"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "AMQP SSL"
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Console Web"
    from_port   = 15672
    to_port     = 15672
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
    Name = "floci-rabbitmq-sg"
  }
}

# ============================================
# REDIS (ElastiCache)
# ============================================
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id          = "floci-redis"
  description                   = "Redis cluster local via Floci"
  engine                        = "redis"
  engine_version                = "7.0"
  node_type                     = "cache.t4g.small"
  num_cache_clusters            = 1
  port                          = 6379
  automatic_failover_enabled    = false
  multi_az_enabled              = false
  at_rest_encryption_enabled    = false
  transit_encryption_enabled    = false

  tags = {
    Name        = "floci-redis"
    Environment = "local"
    ManagedBy   = "Terraform"
  }
}

# ============================================
# RABBITMQ (Amazon MQ)
# ============================================
resource "aws_mq_broker" "rabbitmq" {
  broker_name = "floci-rabbitmq"

  engine_type        = "RABBITMQ"
  engine_version     = "3.13"
  host_instance_type = "mq.m7g.large"
  deployment_mode    = "SINGLE_INSTANCE"

  user {
    username       = "admin"
    password       = "6GKHuxfNcscRNd"
    console_access = true
  }

  publicly_accessible = true

  tags = {
    Name        = "floci-rabbitmq"
    Environment = "local"
    ManagedBy   = "Terraform"
  }
}

# ============================================
# OUTPUTS
# ============================================
output "vpc_id" {
  value = aws_vpc.main.id
}

output "redis_primary_endpoint" {
  description = "Endpoint primário do Redis"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_port" {
  description = "Porta do Redis"
  value       = aws_elasticache_replication_group.redis.port
}

output "rabbitmq_console_url" {
  description = "URL do console de gerenciamento"
  value       = aws_mq_broker.rabbitmq.instances[0].console_url
}

output "rabbitmq_amqp_endpoint" {
  description = "Endpoint AMQP"
  value       = aws_mq_broker.rabbitmq.instances[0].endpoints[0]
}

output "rabbitmq_username" {
  value = "admin"
}

output "rabbitmq_password" {
  sensitive = true
  value     = "6GKHuxfNcscRNd"
}