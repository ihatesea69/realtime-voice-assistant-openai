# Terraform configuration for HieuNghi Voice Agent on AWS EC2 with ALB

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
  default     = "hieunghi"
}

variable "turn_credential" {
  description = "TURN Server Credential"
  type        = string
  sensitive   = true
  default     = "voiceagent"
}

variable "domain_name" {
  description = "Domain name for ALB (e.g., nghidanh.me)"
  type        = string
  default     = "nghidanh.me"
}

# Get Default VPC
data "aws_vpc" "default" {
  default = true
}

# Get Default Subnets (for ALB - only PUBLIC subnets)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# Get subnet details to filter by unique AZ
data "aws_subnet" "selected" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

locals {
  # Get one subnet per AZ
  az_subnet_map  = { for s in data.aws_subnet.selected : s.availability_zone => s.id... }
  unique_subnets = [for az, subnets in local.az_subnet_map : subnets[0]]
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

# Security Group for EC2
resource "aws_security_group" "voice_agent" {
  name        = "hieunghi-voice-agent-sg"
  description = "Security group for HieuNghi Voice Agent"
  vpc_id      = data.aws_vpc.default.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  # HTTP from ALB
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB"
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

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "hieunghi-alb-sg"
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "hieunghi-alb-sg"
    Owner = var.owner
  }
}

# ACM Certificate
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name  = "hieunghi-voice-agent-cert"
    Owner = var.owner
  }
}

# ACM Certificate Validation (waits for DNS validation to complete)
resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn

  timeouts {
    create = "30m"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "hieunghi-voice-agent-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.unique_subnets

  enable_deletion_protection = false

  tags = {
    Name  = "hieunghi-voice-agent-alb"
    Owner = var.owner
  }
}

# Target Group
resource "aws_lb_target_group" "main" {
  name     = "hieunghi-voice-agent-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  # Stickiness for WebSocket
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = {
    Name  = "hieunghi-voice-agent-tg"
    Owner = var.owner
  }
}

# HTTP Listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  depends_on = [aws_acm_certificate_validation.main]
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

# Target Group Attachment
resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.voice_agent.id
  port             = 80
}

# Outputs
output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.voice_agent.public_ip
}

output "alb_dns_name" {
  description = "ALB DNS Name (point your domain CNAME here)"
  value       = aws_lb.main.dns_name
}

output "https_url" {
  description = "HTTPS URL (after DNS setup)"
  value       = "https://${var.domain_name}"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.voice_agent.public_ip}"
}

output "acm_validation_record" {
  description = "CNAME record to add on Namecheap for ACM validation"
  value = { for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
    name  = dvo.resource_record_name
    type  = dvo.resource_record_type
    value = dvo.resource_record_value
  } }
}

output "domain_cname_target" {
  description = "Point your domain A record or CNAME to this ALB"
  value       = aws_lb.main.dns_name
}
