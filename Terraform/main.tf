provider "aws" {
    region = "us-east-1"
}

resource "aws_vpc" "chat_app_vpc" {
    cidr_block = "10.0.0.0/16"
    
    tags = {
    Name = "chat-app-vpc"
    }
}

resource "aws_subnet" "chat_app_subnet" {
    count = 2
    vpc_id = aws_vpc.chat_app_vpc.id
    cidr_block = cidrsubnet(aws_vpc.chat_app_vpc.cidr_block, 8, count.index)
    availability_zone = element(["us-east-1a", "us-east-1b"], count.index)
    map_public_ip_on_launch = true

    tags = {
        Name = "chat-app-subnet-${count.index}"
    }
}

resource "aws_internet_gateway" "chat_app_igw" {
    vpc_id = aws_vpc.chat_app_vpc.id
    
    tags = {
        Name = "chat-app-igw"
    }
}

resource "aws_route_table" "chat_app_route_table" {
    vpc_id = aws_vpc.chat_app_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.chat_app_igw.id
    }

    tags = {
        Name = "chat-app-route-table"
    }
}

resource "aws_route_table_association" "a" {
    count = 2
    subnet_id = aws_subnet.chat_app_subnet[count.index].id
    route_table_id = aws_route_table.chat_app_route_table.id
}

resource "aws_security_group" "chat_app_cluster_sg" {
    vpc_id = aws_vpc.chat_app_vpc.id

    ingress {
        description = "Allow EKS API access"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "chat-app-cluster-sg"
    }
}

resource "aws_security_group" "chat_app_node_sg" {
    vpc_id = aws_vpc.chat_app_vpc.id

    ingress {
        description = "Allow all traffic from the cluster security group"
        from_port = 0
        to_port = 0
        protocol = "-1"
        security_groups = [aws_security_group.chat_app_cluster_sg.id]
    }

    ingress {
        description = "Allow HTTP traffic"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Allow HTTPS traffic"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Allow NodePort access from Internet"
        from_port = 30000
        to_port = 32767
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "chat-app-node-sg"
    }
}

resource "aws_security_group_rule" "Allow Node to cluster" {
    description = "Allow all trafic from node security group to cluster security group"
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    security_group_id = aws_security_group.chat_app_cluster_sg.id
    source_security_group_id = aws_security_group.chat_app_node_sg.id
}

resource "aws_eks_cluster" "chat_app" {
    name     = "chat-app-cluster"
    role_arn = aws_iam_role.chat_app_cluster_role.arn

    vpc_config {
        subnet_ids = aws_subnet.chat_app_subnet[*].id
        security_group_ids = [aws_security_group.chat_app_cluster_sg.id]
    }
}

resource "aws_iam_role" "chat_app_cluster_role" {
    name = "chat-app-cluster-role"

    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
        "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "chat_app_cluster_role_policy" {
    role = aws_iam_role.chat_app_cluster_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "chat_app_node_group_role" {
    name = "chat-app-node-group-role"

    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Effect": "Allow",
        "Principal": {
        "Service": "ec2.amazonaws.com"
    },
        "Action": "sts:AssumeRole"
    }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "chat_app_node_group_role_policy" {
    role       = aws_iam_role.chat_app_node_group_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "chat_app_node_group_cni_policy" {
    role       = aws_iam_role.chat_app_node_group_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "chat_app_node_group_registry_policy" {
    role       = aws_iam_role.chat_app_node_group_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "chat_app" {
    cluster_name = aws_eks_cluster.chat_app.name
    node_group_name = "chat-app-node-group"
    node_role_arn = aws_iam_role.chat_app_node_group_role.arn
    subnet_ids = aws_subnet.chat_app_subnet[*].id

    scaling_config {
        desired_size = 3
        max_size = 3
        min_size = 3
    }

    instance_types = ["t2.large"]

    remote_access {
        ec2_ssh_key = var.ssh_key_name
        source_security_group_ids = [aws_security_group.chat_app_node_sg.id]
    }

    depends_on = [
        aws_iam_role_policy_attachment.chat_app_node_group_role_policy,
        aws_iam_role_policy_attachment.chat_app_node_group_cni_policy,
        aws_iam_role_policy_attachment.chat_app_node_group_registry_policy,
    ]
}