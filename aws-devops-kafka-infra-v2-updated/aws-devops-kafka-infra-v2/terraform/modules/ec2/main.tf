# Fetch latest Ubuntu 22.04 AMI for ap-south-1
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# ----- Bastion Host (jump box for SSH/Ansible into private subnet) -----
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.bastion_sg_id]
  key_name               = var.ssh_key_name
  iam_instance_profile   = var.iam_instance_profile

  tags = {
    Name        = "${var.project_name}-bastion"
    Environment = var.environment
  }
}

# ----- Kafka Brokers (3 nodes across private subnets) -----
resource "aws_instance" "kafka" {
  count                  = 3
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.kafka_instance_type
  subnet_id              = var.private_subnet_ids[count.index]
  vpc_security_group_ids = [var.kafka_sg_id]
  key_name               = var.ssh_key_name
  iam_instance_profile   = var.iam_instance_profile

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name            = "${var.project_name}-kafka-${count.index + 1}"
    Environment     = var.environment
    kafka_broker_id = tostring(count.index + 1)
  }
}

# ----- Persistent EBS volumes for Kafka data -----
resource "aws_ebs_volume" "kafka_data" {
  count             = 3
  availability_zone = aws_instance.kafka[count.index].availability_zone
  size              = 50
  type              = "gp3"
  encrypted         = true

  tags = {
    Name        = "${var.project_name}-kafka-data-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_volume_attachment" "kafka_data_attach" {
  count       = 3
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.kafka_data[count.index].id
  instance_id = aws_instance.kafka[count.index].id
}

# ----- AUTO-GENERATE Ansible Inventory after all EC2 instances are launched -----
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    bastion_ip = aws_instance.bastion.public_ip
    kafka_ips  = aws_instance.kafka[*].private_ip
  })

  # Path is relative to repo root: ansible/inventory/hosts.yml
  filename        = "${path.root}/../ansible/inventory/hosts.yml"
  file_permission = "0644"

  depends_on = [
    aws_instance.bastion,
    aws_instance.kafka,
  ]
}
