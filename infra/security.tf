# Regras de Firewall (Ingress e Egress Restrito)

resource "google_compute_firewall" "allow_ssh_iap" {
  name        = "fw-allow-ssh-iap"
  description = "Permite acesso SSH apenas pela faixa do Identity-Aware Proxy (IAP)."
  network     = google_compute_network.vpc.name
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.iap_cidr]
  target_tags   = ["ssh-iap"]
}

resource "google_compute_firewall" "allow_mysql_internal" {
  name        = "fw-allow-mysql-internal"
  description = "Permite tráfego MySQL (3306) apenas das sub-redes internas da VPC."
  network     = google_compute_network.vpc.name
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }

  source_ranges = [var.subnet_connector_cidr, var.subnet_private_cidr]
}

resource "google_compute_firewall" "allow_egress_web_dns" {
  name        = "fw-allow-egress-web-dns"
  description = "Permite saída apenas para HTTP, HTTPS e DNS para atualização de pacotes."
  network     = google_compute_network.vpc.name
  direction   = "EGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "53"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["ssh-iap"]
}

resource "google_compute_firewall" "allow_egress_mysql_internal" {
  name        = "fw-allow-egress-mysql-internal"
  description = "Permite saída da VM privada na porta 3306 para a faixa privada do Cloud SQL."
  network     = google_compute_network.vpc.name
  direction   = "EGRESS"
  priority    = 1010

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }

  destination_ranges = [
    var.vpc_cidr,
    "${google_compute_global_address.private_ip_address.address}/${google_compute_global_address.private_ip_address.prefix_length}",
  ]
}

resource "google_compute_firewall" "deny_all_egress" {
  name        = "fw-deny-all-egress"
  description = "Bloqueia todo tráfego de saída não autorizado explicitamente (controle S2)."
  network     = google_compute_network.vpc.name
  direction   = "EGRESS"
  priority    = 65534

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}

# Criptografia em Repouso (Cloud KMS - Controle S6)

resource "google_kms_key_ring" "keyring" {
  name     = "marmitech-keyring"
  location = var.region

  depends_on = [google_project_service.enabled_apis]
}

resource "google_kms_crypto_key" "disk_key" {
  name            = "marmitech-disk-key"
  key_ring        = google_kms_key_ring.keyring.id
  rotation_period = "7776000s"
  labels          = var.labels
}

resource "google_kms_crypto_key_iam_member" "compute_kms" {
  crypto_key_id = google_kms_crypto_key.disk_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@compute-system.iam.gserviceaccount.com"
}

resource "google_project_service_identity" "sqladmin_sa" {
  provider = google-beta
  project  = var.project_id
  service  = "sqladmin.googleapis.com"

  depends_on = [google_project_service.enabled_apis]
}

resource "google_kms_crypto_key_iam_member" "sql_kms" {
  crypto_key_id = google_kms_crypto_key.disk_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.sqladmin_sa.email}"
}

# Identidades com Menor Privilégio (Service Accounts - Controle S5)

resource "google_service_account" "vm_sa" {
  account_id   = "marmitech-vm-sa"
  display_name = "Service Account da VM Privada"
}

resource "google_project_iam_member" "vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}

resource "google_service_account" "cloud_run_sa" {
  account_id   = "marmitech-run-sa"
  display_name = "Service Account do Cloud Run"
}

resource "google_project_iam_member" "run_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Gestão de Segredos (Secret Manager - Controle S4)

resource "google_secret_manager_secret" "db_password" {
  secret_id = "marmitech-db-password"
  labels    = var.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.enabled_apis]
}

resource "google_secret_manager_secret_version" "db_password_val" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

resource "google_secret_manager_secret_iam_member" "run_db_password_access" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "marmitech-jwt-secret"
  labels    = var.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.enabled_apis]
}

resource "google_secret_manager_secret_version" "jwt_secret_val" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = var.jwt_secret
}

resource "google_secret_manager_secret_iam_member" "run_jwt_secret_access" {
  secret_id = google_secret_manager_secret.jwt_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}
