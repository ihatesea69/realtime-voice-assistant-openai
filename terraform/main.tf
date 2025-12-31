# Terraform configuration for HieuNghi Voice Agent - ECS Fargate + Cognito

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

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "hieunghi-voice"
}

variable "owner" {
  description = "Owner tag"
  type        = string
}

variable "openai_api_key" {
  description = "OpenAI API Key"
  type        = string
  sensitive   = true
}

variable "key_name" {
  description = "EC2 Key Pair name for CoTURN"
  type        = string
}

# VPC Data Sources
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

data "aws_subnet" "selected" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.value
}

locals {
  az_subnet_map  = { for s in data.aws_subnet.selected : s.availability_zone => s.id... }
  unique_subnets = [for az, subnets in local.az_subnet_map : subnets[0]]
}
