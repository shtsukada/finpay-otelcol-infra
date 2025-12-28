output "instance_public_ip" {
  value = aws_instance.k3s.public_ip
}

output "instance_id" {
  value = aws_instance.k3s.id
}
