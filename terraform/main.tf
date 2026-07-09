module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "security_groups" {
  source = "./modules/security_groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
}

module "ec2" {
  source = "./modules/ec2"

  project_name          = var.project_name
  environment           = var.environment
  public_subnet_ids     = module.vpc.public_subnet_ids
  private_subnet_ids    = module.vpc.private_subnet_ids
  bastion_sg_id         = module.security_groups.bastion_sg_id
  kafka_sg_id           = module.security_groups.kafka_sg_id
  iam_instance_profile  = module.iam.ec2_instance_profile_name
  bastion_instance_type = var.bastion_instance_type
  kafka_instance_type   = var.kafka_instance_type
  kafka_broker_count    = var.kafka_broker_count
  ssh_key_name          = var.ssh_key_name
}
