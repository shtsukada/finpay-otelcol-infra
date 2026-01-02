output "instance_public_ip" {
  value       = aws_instance.k3s.public_ip
  description = "EC2 public IP (for SSH)"
}

output "instance_id" {
  value = aws_instance.k3s.id
}

output "ssh_command" {
  value       = "ssh ubuntu@${aws_instance.k3s.public_ip}"
  description = "SSH command (add -i <key.pem> if needed)"
}
