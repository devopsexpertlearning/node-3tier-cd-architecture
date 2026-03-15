output "metrics_server_release_name" {
  description = "Name of the Metrics Server Helm release"
  value       = var.enable_metrics_server ? helm_release.metrics_server[0].name : null
}

output "envoy_gateway_release_name" {
  description = "Name of the Envoy Gateway Helm release"
  value       = var.enable_envoy_gateway ? helm_release.envoy_gateway[0].name : null
}

output "velero_release_name" {
  description = "Name of the Velero Helm release"
  value       = var.enable_velero ? helm_release.velero[0].name : null
}
