all:
  hosts:
    bastion:
      ansible_host: ${bastion_ip}
      ansible_user: ubuntu
    jenkins:
      ansible_host: ${jenkins_ip}
      ansible_user: ubuntu
  children:
    kafka_brokers:
      hosts:
%{ for i, ip in kafka_ips ~}
        kafka${i + 1}:
          ansible_host: ${ip}
          ansible_user: ubuntu
          broker_id: ${i + 1}
%{ endfor ~}
    kafka_ui:
      hosts:
        kafkaui:
          ansible_host: ${kafka_ui_ip}
          ansible_user: ubuntu
