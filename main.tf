data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "app" {
  count                  = 3
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.small"
  key_name               = "app-operator"
  subnet_id              = element(module.vpc.private_subnets, count.index)
  vpc_security_group_ids = [aws_security_group.app.id, aws_security_group.app_db.id]

  tags = {
    Name        = format("app%02d", count.index + 1)
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<EOF
#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install ssl-cert nginx -y

sed -i 's|# listen 443|listen 443|' /etc/nginx/sites-available/default
sed -i 's|# include snippets/snakeoil|include snippets/snakeoil|' /etc/nginx/sites-available/default

echo "Hello, I am $HOSTNAME and I connect to postgresql on ${aws_db_instance.app_db.endpoint}" > /var/www/html/index.html

service nginx enable
service nginx stop && service nginx start
service postgresql start
EOF
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.small"
  key_name               = "app-operator"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = {
    Name = "bastion"
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# generate a random initial password for the RDS admin account
resource "random_uuid" "db_password" {}

resource "aws_db_instance" "app_db" {
  name                   = "app"
  identifier             = "app-test"
  allocated_storage      = 80
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "10.6"
  instance_class         = "db.t2.small"
  username               = "dbadmin"
  password               = random_uuid.db_password.result
  vpc_security_group_ids = [aws_security_group.app_db.id]
  db_subnet_group_name   = module.vpc.database_subnet_group
  skip_final_snapshot    = true

  tags = {
    Environment = "test"
  }
}

output "bastion_ip_address" {
  value = aws_instance.bastion.public_ip
  description = "The public IP address of the bastion server"
}
