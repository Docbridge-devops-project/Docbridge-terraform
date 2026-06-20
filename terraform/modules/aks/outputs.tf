output "cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "workload_identity_client_id" {
  value = azurerm_user_assigned_identity.workload.client_id
}

output "workload_identity_principal_id" {
  value = azurerm_user_assigned_identity.workload.principal_id
}

output "aks_oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}
