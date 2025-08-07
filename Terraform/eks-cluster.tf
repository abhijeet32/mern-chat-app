module "eks_cluster"{
    source = "terraform-aws-modules/eks/aws"
    version = "20.8.0"

    cluster_name = var.cluster_name
    cluster_version = "1.21"

    subnet_ids = module.vpc.private_subnets
    vpc_id = module.vpc.vpc_id

    enable_irsa = true

    eks_managed_node_groups = {
        default = {
            instance_type = ["t3.medium"]
            min_size = 1
            max_size = 3
            desired_size = 2
        }
    }

    tags = {
        Environment = "dev"
        Terraform = "true"
    }
}