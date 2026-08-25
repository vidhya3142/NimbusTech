resource "aws_security_group" "alb" {
  name        = "nimbus-${var.environment}-alb-sg"
  description = "Public ALB; only HTTP/HTTPS ingress."
  vpc_id      = aws_vpc.this.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from the internet"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from the internet"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  description                  = "ALB to application tier"
}

resource "aws_security_group" "app" {
  name        = "nimbus-${var.environment}-app-sg"
  description = "Private application tier; accepts traffic only from ALB."
  vpc_id      = aws_vpc.this.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  description                  = "Node.js API only from ALB"
}

resource "aws_vpc_security_group_egress_rule" "app_outbound" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Application outbound via NAT for updates/external APIs"
}

resource "aws_security_group" "rds" {
  name        = "nimbus-${var.environment}-rds-sg"
  description = "Private PostgreSQL; accepts DB traffic only from app tier."
  vpc_id      = aws_vpc.this.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_app" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL from application tier"
}

resource "aws_vpc_security_group_egress_rule" "rds_outbound" {
  security_group_id = aws_security_group.rds.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "RDS response traffic"
}

resource "aws_iam_role" "ec2_ssm" {
  name = "nimbus-${var.environment}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "nimbus-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_ssm.name
}
