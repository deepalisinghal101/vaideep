output "bastion_public_ip" { value = aws_instance.bastion.public_ip }
output "kafka_private_ips" { value = aws_instance.kafka[*].private_ip }
output "ansible_inventory_path" { value = local_file.ansible_inventory.filename }
