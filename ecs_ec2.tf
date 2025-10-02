# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# Latest ECS-Optimized Amazon Linux 2 AMI via SSM
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# Launch Template for EC2 container instance
resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.instance_type
  key_name      = length(var.ssh_key_name) > 0 ? var.ssh_key_name : null

  iam_instance_profile { name = aws_iam_instance_profile.ecs_instance_profile.name }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
    # optional: smaller CloudWatch logs disk usage
    echo "ECS_IMAGE_PULL_BEHAVIOR=prefer-cached" >> /etc/ecs/ecs.config
  EOF
  )

  network_interfaces {
    security_groups             = [aws_security_group.ecs_instances.id]
    associate_public_ip_address = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-ecs-instance" }
  }
}

# Auto Scaling Group: keep 1 free-tier instance
resource "aws_autoscaling_group" "ecs_asg" {
  name                      = "${var.project_name}-asg"
  desired_capacity          = 0
  max_size                  = 0
  min_size                  = 0
  vpc_zone_identifier       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  health_check_type         = "EC2"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  lifecycle { create_before_destroy = true }
}

# Attach ASG to cluster with Capacity Provider
resource "aws_ecs_capacity_provider" "ec2_cp" {
  name = "${var.project_name}-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_asg.arn
    managed_termination_protection = "ENABLED"
    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "attach_cp" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ec2_cp.name]
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2_cp.name
    weight            = 1
    base              = 0
  }
}

