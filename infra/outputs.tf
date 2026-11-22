output "nat_public_ip" {
  description = "IP público estático do Cloud NAT."
  value       = google_compute_address.nat_ip.address
}

output "vm_private_ip" {
  description = "IP privado da instância Compute Engine."
  value       = google_compute_instance.vm_privada.network_interface[0].network_ip
}

output "cloud_sql_private_ip" {
  description = "IP privado da instância Cloud SQL."
  value       = google_sql_database_instance.mysql.private_ip_address
}

output "cloud_run_url" {
  description = "URL do serviço backend no Cloud Run."
  value       = google_cloud_run_v2_service.app.uri
}

output "app_url" {
  description = "URL pública HTTPS da aplicação no Firebase Hosting."
  value       = "https://${var.firebase_site_id}.web.app"
}

output "artifact_registry_repository" {
  description = "Caminho base do repositório Docker no Artifact Registry."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}"
}
