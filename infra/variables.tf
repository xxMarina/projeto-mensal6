variable "project_id" {
  type        = string
  description = "ID do projeto no Google Cloud Platform (GCP)."
}

variable "region" {
  type        = string
  description = "Região principal onde os recursos serão provisionados."
  default     = "southamerica-east1"
}

variable "zone" {
  type        = string
  description = "Zona de disponibilidade principal para recursos zonais (ex.: VM privada)."
  default     = "southamerica-east1-a"
}

variable "vpc_name" {
  type        = string
  description = "Nome da rede VPC customizada do projeto."
  default     = "vpc-marmitech"
}

variable "vpc_cidr" {
  type        = string
  description = "Bloco CIDR principal da rede VPC."
  default     = "10.20.0.0/16"
}

variable "subnet_public_cidr" {
  type        = string
  description = "Bloco CIDR da sub-rede pública (Cloud NAT / saída)."
  default     = "10.20.1.0/24"
}

variable "subnet_private_cidr" {
  type        = string
  description = "Bloco CIDR da sub-rede privada (VM privada e banco)."
  default     = "10.20.10.0/24"
}

variable "subnet_connector_cidr" {
  type        = string
  description = "Bloco CIDR /28 dedicado ao Serverless VPC Access Connector."
  default     = "10.20.100.0/28"
}

variable "vm_machine_type" {
  type        = string
  description = "Família e tipo da máquina virtual privada (Compute Engine)."
  default     = "e2-micro"
}

variable "vm_private_ip" {
  type        = string
  description = "Endereço IP privado estático atribuído à VM privada."
  default     = "10.20.10.15"
}

variable "vm_image" {
  type        = string
  description = "Imagem do sistema operacional da VM privada."
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "db_tier" {
  type        = string
  description = "Família e tamanho da instância do Cloud SQL."
  default     = "db-f1-micro"
}

variable "db_name" {
  type        = string
  description = "Nome do banco de dados MySQL criado no Cloud SQL."
  default     = "marmitech"
}

variable "db_user" {
  type        = string
  description = "Nome do usuário da aplicação no Cloud SQL."
  default     = "marmitech_user"
}

variable "db_password" {
  type        = string
  description = "Senha do usuário do banco de dados (fornecer via TF_VAR_db_password)."
  sensitive   = true
}

variable "jwt_secret" {
  type        = string
  description = "Chave secreta para assinatura de tokens JWT (fornecer via TF_VAR_jwt_secret)."
  sensitive   = true
}

variable "iap_cidr" {
  type        = string
  description = "Faixa CIDR autorizada para acesso SSH via Identity-Aware Proxy (nunca 0.0.0.0/0)."
  default     = "35.235.240.0/20"

  validation {
    condition     = var.iap_cidr != "0.0.0.0/0"
    error_message = "SSH não pode ser liberado para 0.0.0.0/0."
  }
}

variable "ssh_user" {
  type        = string
  description = "Nome do usuário Linux configurado nos metadados SSH da VM."
  default     = "marmitech"
}

variable "ssh_public_key" {
  type        = string
  description = "Chave pública SSH autorizada na VM privada (nunca inserir chave privada)."
}

variable "firebase_site_id" {
  type        = string
  description = "Identificador único do site no Firebase Hosting."
}

variable "cloud_run_image_tag" {
  type        = string
  description = "Tag da imagem Docker da API Marmitech no Artifact Registry."
  default     = "latest"
}

variable "labels" {
  type        = map(string)
  description = "Labels obrigatórias de identificação de projeto, grupo e ambiente."
  default = {
    projeto  = "marmitech"
    grupo    = "marmitech"
    ambiente = "producao"
  }
}
