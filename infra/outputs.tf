output "app_url" {
  description = "URL pública HTTPS da aplicação no Firebase Hosting."
  value       = "https://${google_firebase_hosting_site.site.site_id}.web.app"
}
