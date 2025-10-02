variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "free-ecs"
}

variable "instance_type" {
  description = "EC2 instance type for ECS container instance"
  type        = string
  default     = "t2.micro"
}

variable "ssh_key_name" {
  description = ""
  type        = string
  default     = ""
}

