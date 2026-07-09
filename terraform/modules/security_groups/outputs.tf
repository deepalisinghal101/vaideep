output "bastion_sg_id" { value = aws_security_group.bastion.id }
output "jenkins_sg_id" { value = aws_security_group.jenkins.id }
output "kafka_sg_id" { value = aws_security_group.kafka.id }
output "kafka_ui_sg_id" { value = aws_security_group.kafka_ui.id }
