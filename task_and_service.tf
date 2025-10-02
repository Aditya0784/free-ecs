# CloudWatch log group for container logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

# Simple Nginx container first; replace with ECR image later
locals {
  container_name = "web"
  container_port = 80
}

resource "aws_ecs_task_definition" "web" {
  family                   = "${var.project_name}-task"
  requires_compatibilities = ["EC2"]  # EC2 launch type
  network_mode             = "bridge" # simpler for EC2
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_exec_role.arn

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = "nginx:alpine" # change to "${aws_ecr_repository.app.repository_url}:${var.app_image_tag}" after you push
      essential = true
      portMappings = [
        { containerPort = local.container_port, hostPort = 80, protocol = "tcp" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "web" {
  name            = "${var.project_name}-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 1
  launch_type     = "EC2"

  # No Load Balancer — we map container:80 -> host:80 on the single instance
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  depends_on = [aws_autoscaling_group.ecs_asg]
}

