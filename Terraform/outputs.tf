output "cluster_id" {
    value = aws_eks_cluster.chat-app.id
}

output "node_group_id" {
    value = aws_eks_node_group.chat-app.id
}

output "vpc_id" {
    value = aws_vpc.chat-app_vpc.id
}

output "subnet_ids" {
    value = aws_subnet.chat-app_subnet[*].id
}