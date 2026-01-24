resource "aws_eip" "k3s" {
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-k3s-eip"
  }
}

resource "aws_eip_association" "k3s" {
  allocation_id = aws_eip.k3s.id
  instance_id   = aws_instance.k3s.id
}
