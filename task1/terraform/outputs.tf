output "vpc_id" {
  value = aws_vpc.this.id
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.this.address
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}
