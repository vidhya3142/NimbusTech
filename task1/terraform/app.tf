resource "aws_launch_template" "app" {
  name_prefix   = "nimbus-${var.environment}-app-"
  image_id      = local.ami_id
  instance_type = "t3.medium"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euxo pipefail
    dnf update -y
    # Application deployment intentionally omitted; use CI/CD or a hardened AMI.
    echo "NimbusTech application bootstrap placeholder" > /etc/nimbustech-bootstrap.txt
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "nimbus-${var.environment}-app"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "nimbus-${var.environment}-app-asg"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = [for s in aws_subnet.app : s.id]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  target_group_arns = [aws_lb_target_group.app.arn]

  tag {
    key                 = "Name"
    value               = "nimbus-${var.environment}-app"
    propagate_at_launch = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
