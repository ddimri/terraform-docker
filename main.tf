provider "aws" {
  shared_credentials_file = "${var.home_dir}/.aws/credentials"
  profile = "${var.aws_profile}"
  region = "${var.aws_region}"
}

# Create Management VPC
resource "aws_vpc" "awslogin-mgmt-vpc" {
  cidr_block = "${var.vpc_cidr_block}"
  enable_dns_hostnames = true
  tags {
    Name = "${var.vpc_name}-${var.environment}"
  }
}

# Create security group for Public Subnet
resource "aws_security_group" "awslogin-mgmt-public-subnet-sg" {
  name        = "awslogin-${var.environment}-mgmt-public-subnet-sg "
  description = "Security group for Public Subnets"
  vpc_id      = "${aws_vpc.awslogin-mgmt-vpc.id}"
  # inbound ssh access from FYE DC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.feyedc_cidr_block}", "${var.feyeeng_cidr_block}"] # to be replaced with FEYE DC CIDR Block
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["${var.vpc_cidr_block}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ssh_outbound_access_to_awslogin_servers" {
  type = "egress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  security_group_id = "${aws_security_group.awslogin-mgmt-public-subnet-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-server-sg.id}"
}


resource "aws_security_group_rule" "allow_icmp_from_mgmt_public_subnet_hosts" {
  type = "ingress"
  from_port   = -1
  to_port     = -1
  protocol    = "icmp"
  security_group_id = "${aws_security_group.awslogin-mgmt-public-subnet-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-mgmt-public-subnet-sg.id}"
}

resource "aws_security_group_rule" "allow_ssh_from_mgmt_public_subnet_hosts" {
  type = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  security_group_id = "${aws_security_group.awslogin-mgmt-public-subnet-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-mgmt-public-subnet-sg.id}"
}

resource "aws_security_group_rule" "https_outbound" {
  type = "egress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  security_group_id = "${aws_security_group.awslogin-mgmt-public-subnet-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-server-sg.id}"
}

# Create Command Control Jump Box
resource "aws_instance" "awslogin-ccjumpbox" {
  ami = "${var.ccjumpbox_ami}"
  availability_zone = "${element(var.availability_zones, 0)}"
  #availability_zone = "${lookup(var.availability_zones[count.index]), "1"}"
  instance_type = "${var.instance_type}"
  key_name = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.awslogin-mgmt-public-subnet-sg.id}","${aws_security_group.awslogin-server-sg.id}"]
  subnet_id = "${aws_subnet.public-subnet1.id}"
  associate_public_ip_address = true
  source_dest_check = false
  # Deploy ansible on the jump box
  user_data = "${file("install-ansible.sh")}"
  #count     = "${var.count}"
  lifecycle {
     ignore_changes = ["ami", "user_data"]
  }

  tags {
     Name = "awslogin-${var.environment}-ccjumpbox"
  }
}

resource "aws_eip" "awslogin-ccjumpbox-ip" {
  instance = "${aws_instance.awslogin-ccjumpbox.id}"
  vpc = true
  connection {
     host = "${aws_eip.awslogin-ccjumpbox-ip.public_ip}"
     user = "ubuntu"
     timeout = "90s"
     private_key = "${file(var.private_key)}"
     agent = false
  }

  provisioner "file" {
    source      = "${var.private_key}"
    destination = "~/.ssh/${var.key_name}.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0400 ~/.ssh/${var.key_name}.pem",
    ]
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "awslogin-vpc-igw" {
  vpc_id = "${aws_vpc.awslogin-mgmt-vpc.id}"
  tags {
     Name = "awslogin-${var.project}-igw"
  }
}
# Create NAT Gateways for public-subnet1 routing
resource "aws_nat_gateway" "awslogin-nat-gw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id = "${aws_subnet.public-subnet1.id}"
}
resource "aws_eip" "nat" {
  vpc = true
}
# Public Subnet1 in AZ1
resource "aws_subnet" "public-subnet1" {
  vpc_id                  = "${aws_vpc.awslogin-mgmt-vpc.id}"
  availability_zone =  "${element(var.availability_zones, 0)}"
  cidr_block              = "${var.public_subnet1_cidr_block}"
  map_public_ip_on_launch = true
  tags {
    Name = "${var.vpc_name}-${element(var.availability_zones, 0)}-public-subnet"
  }
}

resource "aws_route_table_association" "public-subnet1" {
  subnet_id      = "${aws_subnet.public-subnet1.id}"
  route_table_id = "${aws_route_table.public-subnet1.id}"
}

resource "aws_route_table" "public-subnet1" {
  vpc_id = "${aws_vpc.awslogin-mgmt-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.awslogin-vpc-igw.id}"
  }

  tags {
    Name = "${var.vpc_name}-${element(var.availability_zones, 0)}-public-subnet"
  }
}

# Create NAT Gateways for public-subnet2 routing

resource "aws_nat_gateway" "awslogin-nat-gw2" {
  allocation_id = "${aws_eip.awslogin-nat-gw2.id}"
  subnet_id = "${aws_subnet.public-subnet2.id}"
}

resource "aws_eip" "awslogin-nat-gw2" {
  vpc = true
}

# Public Subnet2 in AZ2
resource "aws_subnet" "public-subnet2" {
  vpc_id                  = "${aws_vpc.awslogin-mgmt-vpc.id}"
  availability_zone = "${element(var.availability_zones, 1)}"
  cidr_block              = "${var.public_subnet2_cidr_block}"
  map_public_ip_on_launch = true
  tags {
    Name = "${var.vpc_name}-${element(var.availability_zones, 1)}-public-subnet"
  }
}
resource "aws_route_table_association" "public-subnet2" {
  subnet_id      = "${aws_subnet.public-subnet2.id}"
  route_table_id = "${aws_route_table.public-subnet2.id}"
}
resource "aws_route_table" "public-subnet2" {
  vpc_id = "${aws_vpc.awslogin-mgmt-vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.awslogin-vpc-igw.id}"
  }

  tags {
    Name = "${var.vpc_name}-${element(var.availability_zones, 1)}-public-subnet"
  }
}
# Private Subnet1 in AZ1
resource "aws_subnet" "private-subnet1" {
  vpc_id                  = "${aws_vpc.awslogin-mgmt-vpc.id}"
  availability_zone = "${element(var.availability_zones, 0)}"
  cidr_block              = "${var.private_subnet1_cidr_block}"
  tags {
    Name = "${var.vpc_name}-${element(var.availability_zones, 0)}-private-subnet"
  }
}

resource "aws_route_table_association" "private-subnet1" {
  subnet_id      = "${aws_subnet.private-subnet1.id}"
  route_table_id = "${aws_route_table.private-subnet1.id}"
}

resource "aws_route_table" "private-subnet1" {
  vpc_id = "${aws_vpc.awslogin-mgmt-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.awslogin-nat-gw.id}"
  }

  tags {
    Name = "${var.vpc_name}-${element(var.availability_zones, 0)}-private-subnet"
  }
}


# Private Subnet2 in AZ2
resource "aws_subnet" "private-subnet2" {
  vpc_id                  = "${aws_vpc.awslogin-mgmt-vpc.id}"
  availability_zone = "${element(var.availability_zones, 1)}"
  cidr_block              = "${var.private_subnet2_cidr_block}"
  tags {
    Name = "${var.vpc_name}-${element(var.availability_zones, 1)}-private-subnet"
  }
}
resource "aws_route_table_association" "private-subnet2" {
  subnet_id      = "${aws_subnet.private-subnet2.id}"
  route_table_id = "${aws_route_table.private-subnet2.id}"
}
resource "aws_route_table" "private-subnet2" {
  vpc_id = "${aws_vpc.awslogin-mgmt-vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.awslogin-nat-gw2.id}"
  }

  tags {
    Name = "${var.vpc_name}-${element(var.availability_zones, 1)}-private-subnet"
  }
}
# Create security group for awslogin server
resource "aws_security_group" "awslogin-server-sg" {
  name        = "awslogin-${var.environment}-awslogin-srv-sg"
  description = "Security group for awslogin server"
  vpc_id      = "${aws_vpc.awslogin-mgmt-vpc.id}"
  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group_rule" "SSH_access_from_CC_JumpBoxes" {
  type = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  security_group_id = "${aws_security_group.awslogin-server-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-mgmt-public-subnet-sg.id}"
}

resource "aws_security_group_rule" "SSH_access_from_self" {
  type = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  security_group_id = "${aws_security_group.awslogin-server-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-server-sg.id}"
}
resource "aws_security_group_rule" "HTTP_access_from_ALB" {
  type = "ingress"
  from_port   = 4000
  to_port     = 4000
  protocol    = "tcp"
  security_group_id = "${aws_security_group.awslogin-server-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-alb-sg.id}"
}
resource "aws_security_group_rule" "HTTP_access_from_CC_JumpBoxes" {
  type = "ingress"
  from_port   = 4000
  to_port     = 4000
  protocol    = "tcp"
  security_group_id = "${aws_security_group.awslogin-server-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-mgmt-public-subnet-sg.id}"
}

resource "aws_security_group_rule" "Allow_HTTP_access_from_self_sg" {
  type = "ingress"
  from_port   = 4000
  to_port     = 4000
  protocol    = "tcp"
  security_group_id = "${aws_security_group.awslogin-server-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-server-sg.id}"
}

resource "aws_security_group_rule" "allow_icmp_from_awslogin_servers" {
  type = "ingress"
  from_port   = -1
  to_port     = -1
  protocol    = "icmp"
  security_group_id = "${aws_security_group.awslogin-server-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-server-sg.id}"
}

# Create security group for alb
resource "aws_security_group" "awslogin-alb-sg" {
  name        = "awslogin-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = "${aws_vpc.awslogin-mgmt-vpc.id}"
  # Inbound internet access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group_rule" "http_outbound_access_to_awslogin" {
  type = "egress"
  from_port   = 4000
  to_port     = 4000
  protocol    = "tcp"
  security_group_id = "${aws_security_group.awslogin-alb-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-server-sg.id}"
}
resource "aws_security_group_rule" "icmp_outbound_access_to_awslogin" {
  type = "egress"
  from_port   = "-1"
  to_port     = "-1"
  protocol    = "icmp"
  security_group_id = "${aws_security_group.awslogin-alb-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-server-sg.id}"
}
resource "aws_security_group_rule" "ping_outbound_access_to_public_subnets" {
  type = "egress"
  from_port   = "-1"
  to_port     = "-1"
  protocol    = "icmp"
  security_group_id = "${aws_security_group.awslogin-alb-sg.id}"
  source_security_group_id = "${aws_security_group.awslogin-mgmt-public-subnet-sg.id}"
}




# Create ALB
resource "aws_alb" "awslogin_opswest" {
  name = "${var.project}-${var.environment}-alb"
  internal        = false
  subnets = ["${aws_subnet.public-subnet1.id}","${aws_subnet.public-subnet2.id}"]
  security_groups = ["${aws_security_group.awslogin-alb-sg.id}"]
  enable_deletion_protection = false

  }

  resource "aws_alb_listener" "awslogin_opswest_alb_listerner" {
    load_balancer_arn = "${aws_alb.awslogin_opswest.arn}"
    port = "443"
    protocol ="HTTPS"
    certificate_arn = "${var.ssl_certificate}"
    default_action {
    target_group_arn = "${aws_alb_target_group.awslogin-opswest-target-group.arn}"
    type = "forward"
  }
    depends_on = ["aws_autoscaling_group.awslogin_ecs_cluster_instances"]
}

resource "aws_alb_target_group" "awslogin-opswest-target-group" {
  name     = "awslogin-opswest-target-group"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.awslogin-mgmt-vpc.id}"

  health_check {
    path = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    protocol            = "HTTP"
  }
  stickiness {
    type = "lb_cookie"
    enabled = true
  }
}


resource "aws_iam_role" "ecs_service_role" {
    name = "${var.project}_ecs_${var.environment}_service_role"
    assume_role_policy = "${file("policies/ecs-role.json")}"
}

resource "aws_iam_role" "ecs_host_role" {
    name = "${var.project}_ecs_${var.environment}_host_role"
    assume_role_policy = "${file("policies/ecs-role.json")}"
}

# IAM role for ALB to have access to ECS.
resource "aws_iam_role" "awslogin-ecs-alb-role" {
  name = "${var.project}_ecs_alb_${var.environment}_role"
  assume_role_policy = "${file("policies/ecs-role.json")}"
}

# IAM role for the task definition
resource "aws_iam_role" "awslogin-task-role" {
  name = "${var.project}_task_${var.environment}_role"
  assume_role_policy = "${file("policies/ecs-role.json")}"
}

# IAM policies for EC2 instances
resource "aws_iam_role_policy" "ecs_instance_role_policy" {
    name = "${var.project}_ecs_${var.environment}_instance_policy"
    policy = "${file("policies/ec2-instance-role-policy.json")}"
    #policy = "${file("policies/ecs-instance-role-policy.json")}"
    #policy = "${file("policies/cloudwatch-matrics-policy.json")}"
    #policy = "${file("policies/amazon-dynamodb-full-access-policy.json")}"
    role = "${aws_iam_role.ecs_host_role.id}"
}


# Policy attachment for the "awslogin-ecs-role" to provides access to the the ECS service.
resource "aws_iam_role_policy" "ecs_service_role_policy" {
    name = "${var.project}_ecs_${var.environment}_service_role_policy"
    policy = "${file("policies/ecs-service-role-policy.json")}"
    role = "${aws_iam_role.ecs_service_role.id}"
}



# Policy attachment for the "awslogin-ecs-alb-role" to provides access to the the ECS service.
resource "aws_iam_role_policy" "ecs_alb-service_role_policy" {
    name = "ecs_alb-service_role_policy"
    policy = "${file("policies/ecs-service-role-policy.json")}"
    role = "${aws_iam_role.awslogin-ecs-alb-role.id}"
}

resource "aws_iam_role_policy" "awslogin-task-role-policy" {
  name = "${var.project}_task_${var.environment}_role_policy"
  role = "${aws_iam_role.awslogin-task-role.id}"
  policy =  "${file("policies/task-role-policy.json")}"
  #policy =  "${file("policies/dynamodb-ro-policy.json")}"
  #policy =  "${file("policies/OIDC-assume-role-policy.json")}"
}


# ECS cluster
resource "aws_ecs_cluster" "awslogin_ecs_cluster" {
    name = "${var.ecs_cluster_name}"
}


resource "aws_ecs_task_definition" "awslogin_ecs_cluster" {
  family = "awslogin_ecs_cluster"
  container_definitions = "${file("task-definition.json.tmpl")}"
 # role = ["${aws_iam_role.awslogin-task-role.id}"]
 # task_role_arn  = "arn:aws:iam::${var.aws_account}:role/awslogin_task_opswest_role"
  task_role_arn = "arn:aws:iam::157065524616:role/ecs-task-role"
}

resource "aws_autoscaling_group" "awslogin_ecs_cluster_instances" {
  name = "${var.project}_ecs_cluster"
  #availability_zones = "${element(var.availability_zones, count.index)}"
  #availability_zones = "${element(split(",", var.availability_zones))}"
  availability_zones = "${var.availability_zones}"
  vpc_zone_identifier = ["${aws_subnet.public-subnet1.id}", "${aws_subnet.public-subnet2.id}"]
  min_size = "${var.autoscale_min}"
  max_size = "${var.autoscale_max}"
  desired_capacity = "${var.autoscale_desired}"
  launch_configuration = "${aws_launch_configuration.awslogin_ecs_instances.name}"
  target_group_arns = ["${aws_alb_target_group.awslogin-opswest-target-group.arn}"]
  health_check_type = "EC2"
}

# Launch EC2 instances

resource "aws_launch_configuration" "awslogin_ecs_instances" {
  name = "${var.project}_ecs_cluster"
  instance_type = "${var.instance_type}"
  image_id = "${lookup(var.awslogin_server_ami, var.aws_region)}"
  #image_id = "${var.awslogin_server_ami}"
  iam_instance_profile = "${aws_iam_instance_profile.ecs_service_role.id}"
  associate_public_ip_address = true
  security_groups = ["${aws_security_group.awslogin-server-sg.id}"]
  key_name = "${var.key_name}"
  #user_data = "#!/bin/bash\necho ECS_CLUSTER='${var.ecs_cluster_name}' > /etc/ecs/ecs.config"
  user_data = "#!/bin/bash -xe\nsudo docker stop ecs-agent\nsudo docker start ecs-agent"

}


resource "aws_ecs_service" "awslogin_opswest" {
  name = "${var.project}_${var.environment}"
  cluster = "${aws_ecs_cluster.awslogin_ecs_cluster.id}"
  task_definition = "${aws_ecs_task_definition.awslogin_ecs_cluster.arn}"
  desired_count = 2
  iam_role = "${aws_iam_role.ecs_service_role.arn}"
  depends_on = ["aws_iam_role_policy.ecs_service_role_policy"]
  deployment_minimum_healthy_percent = 50

  load_balancer {
    target_group_arn =  "${aws_alb_target_group.awslogin-opswest-target-group.arn}"
    container_name = "awslogin_ecs_cluster"
    container_port = "${var.docker_port}"
  }
}


resource "aws_iam_instance_profile" "ecs_service_role" {
  name = "ecs-instance-profile"
  #name = "${var.project}_${var.environment}"
  path = "/"
  roles = ["${aws_iam_role.ecs_host_role.name}"]
}
