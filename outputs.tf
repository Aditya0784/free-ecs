output "public_instance_ips" {
  description = "Public IP(s) of the ECS container instance(s)"
  value = [
    for i in data.aws_instances.ecs.ids : data.aws_instance.by_id[i].public_ip
  ]
}

data "aws_instances" "ecs" {
  instance_tags        = { Name = "${var.project_name}-ecs-instance" }
  instance_state_names = ["running"]
}

data "aws_instance" "by_id" {
  for_each    = toset(data.aws_instances.ecs.ids)
  instance_id = each.value
}

