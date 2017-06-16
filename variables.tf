variable "aws_region" {
    description = "The AWS region to create resources in."
    default = "us-west-2"
}

#variable "availability_zones" {
 #   default = {
  #  "1" = "us-west-2a"
   # "2" = "us-west-2b"
  #}
#}


variable "availability_zones" {
  type = "list"
  default = ["us-west-2a", "us-west-2b"]
}

variable "aws_account" { default = "398818754185" }

variable "environment" { default = "opswest" }

variable "project" { default = "docker" }

variable "vpc_name" { default = "docker-mgmt-vpc" }

variable "feyedc_cidr_block" { default = "96.46.157.30/32" }

variable "feyeeng_cidr_block" { default = "50.201.125.254/32"}

variable "vpc_cidr_block" { default = "10.88.11.0/24" }

variable "ccjumpbox_ami" { default = "ami-efd0428f" }

variable "private_key" { default = "~/.ssh/e2-key-file.pem" }

variable "public_subnet1_cidr_block" { default = "10.88.11.1/28" }

variable "public_subnet2_cidr_block" { default = "10.88.11.16/28" }

variable "private_subnet1_cidr_block" { default = "10.88.11.32/28" }

variable "private_subnet2_cidr_block" { default = "10.88.11.48/28" }

variable "ssl_certificate" { default = "arn:aws:iam::398818754185:server-certificate/docker-hello-world" }

variable "ecs_cluster_name" {
    description = "The name of the Amazon ECS cluster."
    default = "docker_ecs_cluster"
}

variable "docker_server_ami" {
    default = {
      us-west-2 = "ami-77f0fb0e"
      #us-west-2 = "ami-62d35c02"
    }
}


variable "autoscale_min" {
    default = "1"
    description = "Minimum autoscale (number of EC2)"
}

variable "autoscale_max" {
    default = "3"
    description = "Maximum autoscale (number of EC2)"
}

variable "autoscale_desired" {
    default = "2"
    description = "Desired autoscale (number of EC2)"
}


variable "instance_type" {
    default = "t2.micro"
}

variable "aws_profile" { default = "deepakprasad" }

variable "home_dir" { default = "/Users/deepak.prasad" }

variable "key_name" { default = "e2-key-file" }

variable "docker_port" { default = "80" }

variable "host_port" { default = "80" }
