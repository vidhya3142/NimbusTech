resource "aws_db_subnet_group" "this" {
  name       = "nimbus-${var.environment}-db-subnets"
  subnet_ids = [for s in aws_subnet.db : s.id]

  tags = { Name = "nimbus-${var.environment}-db-subnet-group" }
}

resource "aws_db_instance" "this" {
  identifier = "nimbus-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = "db.t3.medium"

  allocated_storage     = 100
  max_allocated_storage = 500
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.db_port

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  deletion_protection     = true
  skip_final_snapshot     = true

  performance_insights_enabled = true
  auto_minor_version_upgrade   = true

  tags = { Name = "nimbus-${var.environment}-postgres" }
}
