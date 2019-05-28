data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.0.0"

  name = "app-test"
  cidr = "10.168.0.0/16"

  azs              = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets   = ["10.168.1.0/24", "10.168.2.0/24", "10.168.3.0/24"]
  private_subnets  = ["10.168.101.0/24", "10.168.102.0/24", "10.168.103.0/24"]
  database_subnets = ["10.168.111.0/24", "10.168.112.0/24", "10.168.113.0/24"]

  enable_nat_gateway     = true
  one_nat_gateway_per_az = true

  tags = {
    Name        = "app-test"
    Environment = "test"
  }
}

resource "aws_security_group" "app" {
  name        = "app_sg"
  description = "App Server Security Group"
  vpc_id      = module.vpc.vpc_id

  # allow outbound to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "bastion" {
  name        = "bastion_sg"
  description = "Bastion Host Security Group"
  vpc_id      = module.vpc.vpc_id

  # allow outbound to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_db" {
  name        = "app_db_sg"
  description = "App Server DB Security Group"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "allow_public_bastion_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion.id
}

# allow SSH traffic from any member of the Bastion SG
resource "aws_security_group_rule" "allow_bastion_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.bastion.id
}

# allow HTTPS traffic from the Load Balancer
resource "aws_security_group_rule" "allow_lb_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.app_lb.id
}

# allow PGSQL traffic from any member of the AppDB SG
resource "aws_security_group_rule" "allow_pgsql" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.app_db.id
}
