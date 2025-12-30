# Terraform configuration for HieuNghi Voice Agent on AWS EC2

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Name of existing EC2 key pair"
  type        = string
}

variable "openai_api_key" {
  description = "OpenAI API Key"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository URL"
  type        = string
  default     = "https://github.com/ihatesea69/realtime-voice-assistant-openai.git"
}

variable "owner" {
  description = "Owner tag for resources"
  type        = string
}

# Get latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group
resource "aws_security_group" "voice_agent" {
  name        = "hieunghi-voice-agent-sg"
  description = "Security group for HieuNghi Voice Agent"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  # Frontend
  ingress {
    from_port   = 5173
    to_port     = 5173
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Frontend"
  }

  # Backend API
  ingress {
    from_port   = 7860
    to_port     = 7860
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Backend API"
  }

  # WebRTC UDP ports
  ingress {
    from_port   = 40000
    to_port     = 40100
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WebRTC media"
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "hieunghi-voice-agent-sg"
    Owner = var.owner
  }
}

# EC2 Instance
resource "aws_instance" "voice_agent" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.voice_agent.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    openai_api_key = var.openai_api_key
    github_repo    = var.github_repo
  }))

  tags = {
    Name  = "hieunghi-voice-agent"
    Owner = var.owner
  }
}

# Outputs
output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.voice_agent.public_ip
}

output "frontend_url" {
  description = "Frontend URL"
  value       = "http://${aws_instance.voice_agent.public_ip}:5173"
}

output "backend_url" {
  description = "Backend URL"
  value       = "http://${aws_instance.voice_agent.public_ip}:7860"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.voice_agent.public_ip}"
}
