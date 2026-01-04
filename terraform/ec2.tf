data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "ec2_k3s" {
  name        = "${var.name_prefix}-ec2-k3s"
  description = "SSH(22) and k3s API(6443) from allowed_cidrs only"
  vpc_id      = data.aws_subnet.selected.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "k3s API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    description = "all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-ec2-k3s"
  }
}

resource "aws_instance" "k3s" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.ssh_key_name

  vpc_security_group_ids      = [aws_security_group.ec2_k3s.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data/install_k3s.sh.tftpl", {
    k3s_version         = var.k3s_version
    k3s_disable_traefik = var.k3s_disable_traefik
  })

  user_data_replace_on_change = true

  tags = {
    Name = "${var.name_prefix}-k3s"
  }
}
