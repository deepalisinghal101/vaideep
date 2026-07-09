all:
  hosts:
    bastion:
      ansible_host: ${bastion_ip}
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
