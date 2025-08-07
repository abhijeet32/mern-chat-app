module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    version = "5.1.1"
    
    name = "chat-app-vpc"
    cidr = "var.vpc_cidr"

    azs = ["${var.region}a", "${var.region}b"]
    public_subnets = var.public_subnets
    private_subnets = var.private_subnets

    enable_nat_gateway = true
    single_nat_gateway = true

    tags = {
        "kubernetes.io/cluster/${var.cluster_name}" = "shared"
        "Terraform" = "true"
    }
}