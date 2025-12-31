# Network Load Balancer for CoTURN (UDP)

resource "aws_lb" "coturn" {
  name               = "${var.project_name}-coturn-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = local.unique_subnets

  enable_deletion_protection = false

  tags = {
    Name  = "${var.project_name}-coturn-nlb"
    Owner = var.owner
  }
}

# CoTURN Target Group (UDP 3478)
resource "aws_lb_target_group" "coturn" {
  name        = "${var.project_name}-coturn-tg"
  port        = 3478
  protocol    = "UDP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "3478"
    protocol            = "TCP" # NLB uses TCP for health checks
    unhealthy_threshold = 2
  }

  tags = {
    Name  = "${var.project_name}-coturn-tg"
    Owner = var.owner
  }
}

# UDP Listener for TURN signaling
resource "aws_lb_listener" "coturn_udp" {
  load_balancer_arn = aws_lb.coturn.arn
  port              = 3478
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.coturn.arn
  }
}

# TCP Listener for TURN signaling (fallback)
resource "aws_lb_listener" "coturn_tcp" {
  load_balancer_arn = aws_lb.coturn.arn
  port              = 3478
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.coturn_tcp.arn
  }
}

resource "aws_lb_target_group" "coturn_tcp" {
  name        = "${var.project_name}-coturn-tcp-tg"
  port        = 3478
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "3478"
    protocol            = "TCP"
    unhealthy_threshold = 2
  }

  tags = {
    Name  = "${var.project_name}-coturn-tcp-tg"
    Owner = var.owner
  }
}
