output "dev_vpc_id" {
  value = module.vpc.vpc_id
}

output "dev_public_subnets" {
  value = module.vpc.public_subnet_ids
}