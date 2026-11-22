resource "google_compute_instance" "vm_privada" {
  name         = "marmitech-vm-privada"
  machine_type = var.vm_machine_type
  zone         = var.zone
  tags         = ["ssh-iap"]
  labels       = var.labels

  boot_disk {
    kms_key_self_link = data.google_kms_crypto_key.disk_key.id

    initialize_params {
      image  = var.vm_image
      size   = 10
      type   = "pd-standard"
      labels = var.labels
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.privada.id
    network_ip = var.vm_private_ip
    # Sem bloco access_config => sem IP público (Requisito R5)
  }

  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys       = "${var.ssh_user}:${var.ssh_public_key}"
  }

  # Controle S1: desativa autenticação por senha e login direto como root
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    if [ -d /etc/ssh/sshd_config.d ]; then
      printf "PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no\n" > /etc/ssh/sshd_config.d/99-hardening.conf
    fi
    systemctl restart ssh || systemctl restart sshd
  EOT

  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }

  depends_on = [
    google_kms_crypto_key_iam_member.compute_kms,
  ]
}

# Banco de Dados Gerenciado (Cloud SQL MySQL 8.0 + Política Mínima B6)
resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "mysql" {
  name                = "marmitech-mysql-${random_id.db_name_suffix.hex}"
  database_version    = "MYSQL_8_0"
  region              = var.region
  deletion_protection = false
  encryption_key_name = data.google_kms_crypto_key.disk_key.id

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_kms_crypto_key_iam_member.sql_kms,
  ]

  settings {
    tier        = var.db_tier
    disk_type   = "PD_HDD"
    disk_size   = 10
    user_labels = var.labels

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      binary_log_enabled             = true
      transaction_log_retention_days = 2

      backup_retention_settings {
        retained_backups = 2
        retention_unit   = "COUNT"
      }
    }
  }
}

resource "google_sql_database" "app_db" {
  name     = var.db_name
  instance = google_sql_database_instance.mysql.name
}

resource "google_sql_user" "app_user" {
  name     = var.db_user
  instance = google_sql_database_instance.mysql.name
  password = var.db_password
}

# Exportação automática no destroy e restauração automática no apply (GCS persistente)
resource "google_storage_bucket_iam_member" "sql_backup_bucket_access" {
  bucket = "marmitech-sql-backups-515322"
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_sql_database_instance.mysql.service_account_email_address}"
}

resource "terraform_data" "sql_backup_sync" {
  input = {
    instance_name = google_sql_database_instance.mysql.name
    db_name       = google_sql_database.app_db.name
    project_id    = var.project_id
    bucket        = "marmitech-sql-backups-515322"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      if gcloud storage ls "gs://${self.input.bucket}/marmitech-latest.sql" --project="${self.input.project_id}" >/dev/null 2>&1; then
        gcloud sql import sql "${self.input.instance_name}" "gs://${self.input.bucket}/marmitech-latest.sql" \
          --database="${self.input.db_name}" \
          --project="${self.input.project_id}" \
          --quiet
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -eu
      gcloud sql export sql "${self.input.instance_name}" "gs://${self.input.bucket}/marmitech-latest.sql" \
        --database="${self.input.db_name}" \
        --project="${self.input.project_id}" \
        --quiet
    EOT
  }

  depends_on = [
    google_sql_database.app_db,
    google_sql_user.app_user,
    google_storage_bucket_iam_member.sql_backup_bucket_access,
  ]
}

# Artifact Registry
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "marmitech-repo"
  format        = "DOCKER"
  labels        = var.labels

  depends_on = [google_project_service.enabled_apis]
}

resource "terraform_data" "build_and_push_api" {
  triggers_replace = [
    google_artifact_registry_repository.repo.id,
    var.cloud_run_image_tag,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      gcloud auth configure-docker ${var.region}-docker.pkg.dev --quiet
      docker build -t ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}/marmitech-api:${var.cloud_run_image_tag} ${path.module}/..
      docker push ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}/marmitech-api:${var.cloud_run_image_tag}
    EOT
  }

  depends_on = [google_artifact_registry_repository.repo]
}

# Backend API Serverless (Cloud Run v2)
resource "google_cloud_run_v2_service" "app" {
  name                = "marmitech-api"
  location            = var.region
  deletion_protection = false
  labels              = var.labels

  template {
    service_account = google_service_account.cloud_run_sa.email
    labels          = var.labels

    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}/marmitech-api:${var.cloud_run_image_tag}"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "SPRING_DATASOURCE_URL"
        value = "jdbc:mysql://${google_sql_database_instance.mysql.private_ip_address}:3306/${var.db_name}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=America/Sao_Paulo"
      }

      env {
        name  = "SPRING_DATASOURCE_USERNAME"
        value = var.db_user
      }

      env {
        name = "SPRING_DATASOURCE_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [scaling]
  }

  depends_on = [
    terraform_data.build_and_push_api,
    terraform_data.sql_backup_sync,
    google_project_iam_member.run_cloudsql_client,
    google_secret_manager_secret_iam_member.run_db_password_access,
    google_secret_manager_secret_iam_member.run_jwt_secret_access,
    google_secret_manager_secret_version.db_password_val,
    google_secret_manager_secret_version.jwt_secret_val,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Frontend (Firebase Hosting - provider google-beta)
# Nota: O site e os arquivos estáticos + rewrites de API do Angular são publicados
# via CI/CD (marmitech-web/firebase.json + GitHub Actions) para não sobrescrever
# o deploy de produção a cada execução do Terraform.
resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id

  depends_on = [google_project_service.enabled_apis]
}
