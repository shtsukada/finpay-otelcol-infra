output "instance_id" {
  value = aws_instance.k3s.id
}

output "ssh_command" {
  value       = "ssh ubuntu@${aws_eip.k3s.public_ip}"
  description = "SSH command (add -i <key.pem> if needed)"
}

output "eip_public_ip" {
  description = "Elastic IP (fixed public IP for k3s API access)"
  value       = aws_eip.k3s.public_ip
}

output "eip_allocation_id" {
  description = "Elastic IP allocation id"
  value       = aws_eip.k3s.id
}

output "kubeconfig_command" {
  description = "Generate kubeconfig using the fixed EIP"
  value       = "./hack/kubeconfig.sh ${aws_eip.k3s.public_ip}"
}
