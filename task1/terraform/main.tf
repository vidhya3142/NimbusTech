data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets = {
    az1 = { cidr = "10.20.1.0/24", az = local.azs[0] }
    az2 = { cidr = "10.20.2.0/24", az = local.azs[1] }
  }

  app_subnets = {
    az1 = { cidr = "10.20.11.0/24", az = local.azs[0] }
    az2 = { cidr = "10.20.12.0/24", az = local.azs[1] }
  }

  db_subnets = {
    az1 = { cidr = "10.20.21.0/24", az = local.azs[0] }
    az2 = { cidr = "10.20.22.0/24", az = local.azs[1] }
  }

  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.al2023.value
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "nimbus-${var.environment}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "nimbus-${var.environment}-igw" }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = { Name = "nimbus-${var.environment}-public-${each.key}" }
}

resource "aws_subnet" "app" {
  for_each = local.app_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = { Name = "nimbus-${var.environment}-app-${each.key}" }
}

resource "aws_subnet" "db" {
  for_each = local.db_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = { Name = "nimbus-${var.environment}-db-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "nimbus-${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  for_each = local.public_subnets
  domain   = "vpc"
  tags     = { Name = "nimbus-${var.environment}-nat-eip-${each.key}" }
}

resource "aws_nat_gateway" "this" {
  for_each = local.public_subnets

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  depends_on    = [aws_internet_gateway.this]

  tags = { Name = "nimbus-${var.environment}-nat-${each.key}" }
}

resource "aws_route_table" "app" {
  for_each = local.app_subnets

  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }
  tags = { Name = "nimbus-${var.environment}-app-rt-${each.key}" }
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

resource "aws_route_table" "db" {
  for_each = local.db_subnets
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "nimbus-${var.environment}-db-rt-${each.key}" }
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.db[each.key].id
}
