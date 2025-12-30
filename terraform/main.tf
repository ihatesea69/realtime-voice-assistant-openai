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

variable "turn_username" {
  description = "TURN Server Username"
  type        = string
  default     = ""
}

variable "turn_credential" {
  description = "TURN Server Credential"
  type        = string
  sensitive   = true
  default     = ""
}

variable "domain_name" {
  description = "Domain name for Nginx"
  type        = string
  default     = ""
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

  # HTTP (for Let's Encrypt verification)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
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

  # WebRTC UDP ports (Media)
  ingress {
    from_port   = 40000
    to_port     = 40100
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WebRTC media"
  }

  # CoTURN Signaling (TCP/UDP)
  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN Signaling TCP"
  }

  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN Signaling UDP"
  }

  # CoTURN Relay Ports (UDP)
  ingress {
    from_port   = 49152
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN Relay UDP"
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

# CloudFront Distribution
resource "aws_cloudfront_distribution" "voice_agent_cdn" {
  origin {
    domain_name = aws_instance.voice_agent.public_dns
    origin_id   = "EC2Origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # CloudFront -> EC2 is HTTP
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "HieuNghi Voice Agent CDN"
  default_root_object = "index.html"

  # Default Cache Behavior (Frontend)
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "EC2Origin"

    forwarded_values {
      query_string = true
      headers      = ["*"] # Forward all headers (Host, Upgrade, etc.)
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0 # Disable caching for now to avoid issues
    max_ttl                = 0
  }

  # API Cache Behavior
  ordered_cache_behavior {
    path_pattern     = "/offer"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "EC2Origin"

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  # Viewer Certificate (Default *.cloudfront.net HTTPS)
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name  = "hieunghi-voice-agent-cdn"
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
    openai_api_key  = var.openai_api_key
    github_repo     = var.github_repo
    turn_username   = var.turn_username
    turn_credential = var.turn_credential
    domain_name     = var.domain_name
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

output "cloudfront_url" {
  description = "CloudFront URL (HTTPS)"
  value       = "https://${aws_cloudfront_distribution.voice_agent_cdn.domain_name}"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.voice_agent.public_ip}"
}
