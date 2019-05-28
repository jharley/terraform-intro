data "aws_acm_certificate" "wildcard" {
  domain      = "*.redmind.xyz"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

resource "aws_security_group" "app_lb" {
  name        = "app_lb_sg"
  description = "App Server Load Balancer Security Group"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_lb" "app" {
  name               = "app-test"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.app_lb.id]

  tags = {
    Name        = "app-test"
    Environment = "test"
  }
}

resource "aws_security_group_rule" "allow_inbound_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app_lb.id
}

resource "aws_security_group_rule" "allow_lb_healthcheck" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_lb.id
  source_security_group_id = aws_security_group.app.id
}

resource "aws_lb_target_group" "app" {
  name     = "app-test"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    interval            = 5
    protocol            = "HTTPS"
    timeout             = 2
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "app_https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.wildcard.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# add each app instance to the target group
resource "aws_lb_target_group_attachment" "app" {
  count            = length(aws_instance.app[*].id)
  target_group_arn = aws_lb_target_group.app.arn
  port             = 443
  target_id        = aws_instance.app[count.index].id
}
