output "cluster_id" {
    value = aws_eks_cluster.chat_app.id
}

output "node_group_id" {
    value = aws_eks_node_group.chat_app.id
}

output "vpc_id" {
    value = aws_vpc.chat_app_vpc.id
}

output "subnet_ids" {
    value = aws_subnet.chat_app_subnet[*].id
}