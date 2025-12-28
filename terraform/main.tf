resource "aws_security_group" "main" {
  name = "${var.name_prefix}-sg"
  description = "finpay-otelcol minimal SG"
  vpc_id = data.aws_subnet.selected.vpc_id

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "k8s api"
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sg"
  }
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"] # Canonical

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "k3s" {
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id = var.subnet_id
  vpc_security_group_ids = [ aws_security_group.main.id ]
  key_name = var.ssh_key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data/install_k3s.sh.tftpl", {
    k3s_version = var.k3s_version
  })

  tags = {
    Name = "${var.name_prefix}-k3s"
  }
}