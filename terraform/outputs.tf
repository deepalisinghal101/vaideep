output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "bastion_public_ip" {
  description = "Bastion Host public IP"
  value       = module.ec2.bastion_public_ip
}

output "jenkins_public_ip" {
  description = "Jenkins server public IP"
  value       = module.ec2.jenkins_public_ip
}

output "kafka_broker_private_ips" {
  description = "Kafka brokers private IPs"
  value       = module.ec2.kafka_private_ips
}

output "kafka_ui_public_ip" {
  description = "Kafka UI public IP"
  value       = module.ec2.kafka_ui_public_ip
}

output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory file"
  value       = module.ec2.ansible_inventory_path
}
