variable "project_id" {
  type        = string
  description = "ID do projeto no Google Cloud Platform (GCP)."
}

variable "region" {
  type        = string
  description = "Região padrão do projeto."
  default     = "southamerica-east1"
}

variable "firebase_site_id" {
  type        = string
  description = "Identificador único do site no Firebase Hosting."
}
