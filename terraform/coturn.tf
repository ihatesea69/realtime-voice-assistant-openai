# CoTURN EC2 Auto Scaling Group

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for CoTURN
resource "aws_security_group" "coturn" {
  name        = "${var.project_name}-coturn-sg"
  description = "Security group for CoTURN server"
  vpc_id      = data.aws_vpc.default.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  # TURN signaling TCP
  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN TCP"
  }

  # TURN signaling UDP
  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN UDP"
  }

  # TURN relay ports
  ingress {
    from_port   = 49152
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN Relay UDP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.project_name}-coturn-sg"
    Owner = var.owner
  }
}

# Launch Template for CoTURN
resource "aws_launch_template" "coturn" {
  name_prefix   = "${var.project_name}-coturn-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.coturn.id]

  user_data = base64encode(<<-EOF
#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

apt-get update
apt-get install -y coturn curl

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Enable CoTURN
sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/g' /etc/default/coturn

# Configure CoTURN
cat > /etc/turnserver.conf << CONF
listening-port=3478
listening-ip=$PRIVATE_IP
external-ip=$PUBLIC_IP/$PRIVATE_IP
relay-ip=$PRIVATE_IP
fingerprint
lt-cred-mech
user=hieunghi:voiceagent
realm=voiceagent
min-port=49152
max-port=65535
log-file=/var/log/turnserver.log
verbose
CONF

systemctl restart coturn
echo "CoTURN configured with external IP: $PUBLIC_IP"
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name  = "${var.project_name}-coturn"
      Owner = var.owner
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "coturn" {
  name                = "${var.project_name}-coturn-asg"
  vpc_zone_identifier = local.unique_subnets
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.coturn.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.coturn.arn,
    aws_lb_target_group.coturn_tcp.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "${var.project_name}-coturn"
    propagate_at_launch = true
  }

  tag {
    key                 = "Owner"
    value               = var.owner
    propagate_at_launch = true
  }
}

# Auto Scaling Policy
resource "aws_autoscaling_policy" "coturn_cpu" {
  name                   = "${var.project_name}-coturn-cpu"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.coturn.name

  target_tracking_configuration {
    target_value = 60.0
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}
