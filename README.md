# Sistema de Gerenciamento de Pedidos — Marmitech

Projeto Integrador (6º Período de Engenharia de Software — Uniamérica Descomplica | Prof. Gildomiro Bairros).  
Aplicação web para cardápio online, gestão de pedidos e fila de atendimento de cozinha, implantada na **Google Cloud Platform (GCP)** na região `southamerica-east1` (São Paulo) utilizando **Terraform**, **Cloud Run**, **Cloud SQL (MySQL 8.0)**, **Firebase Hosting**, **Cloud NAT**, **Secret Manager** e **Cloud KMS**.

> **Aviso de Custos:** Este projeto cria recursos pagos por hora na GCP (**Cloud NAT**, **IP público estático**, **Cloud SQL** e **VPC Access Connector**), mesmo sem tráfego. Configure um **alerta de orçamento** antes do primeiro `apply`, mantenha a infraestrutura ligada apenas durante testes e apresentação, e execute `terraform destroy` ao concluir cada sessão.

---

## 1. Integrantes do Grupo

- *Fabricio Ricardo Castillo Quintana*
- *Marina Pires Ramos*

---

## 2. Estrutura da Infraestrutura (`infra/`)

- `infra/versions.tf` — Versão mínima do Terraform (`>= 1.5.0`) e providers `google` / `google-beta`.
- `infra/providers.tf` — Configuração dos providers e habilitação das APIs da GCP.
- `infra/variables.tf` — Definição de todas as variáveis (região, zona, CIDRs, instâncias, IAP, labels e segredos `sensitive = true`).
- `infra/network.tf` — VPC `vpc-marmitech`, sub-redes (`public`, `private`, `vpc-connector`), Cloud Router, IP estático, Cloud NAT (`MANUAL_ONLY`), VPC Peering e Serverless VPC Access Connector.
- `infra/security.tf` — Regras de firewall (SSH via IAP e `EGRESS` restrito — S2), Cloud KMS/CMEK (S6), Service Accounts de menor privilégio (S5) e Secret Manager (S4).
- `infra/compute.tf` — VM privada `e2-micro` (sem IP público, endurecimento SSH — S1), Cloud SQL MySQL 8.0 (backup mínimo de 2 cópias — B6), Artifact Registry, Cloud Run v2 e Firebase Hosting.
- `infra/outputs.tf` — IP público do NAT, IPs privados (VM e Cloud SQL) e URLs da aplicação.
- `infra/terraform.tfvars.example` — Modelo de variáveis (sem segredos).

---

## 3. Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/downloads) `>= 1.5.0`
- [Google Cloud CLI (`gcloud`)](https://cloud.google.com/sdk/docs/install) autenticado (`gcloud auth login` e `gcloud auth application-default login`)
- [Docker](https://docs.docker.com/get-docker/) (para build e push da imagem do backend)
- [Node.js 20+](https://nodejs.org/) e [Firebase CLI](https://firebase.google.com/docs/cli) (para build e deploy do frontend Angular)
- Par de chaves SSH gerado localmente (`ssh-keygen -t ed25519 -f ~/.ssh/marmitech-key`).

---

## 4. Configuração das Variáveis

1. Copie o arquivo de exemplo:

   ```bash
   cp infra/terraform.tfvars.example infra/terraform.tfvars
   ```

2. Preencha `infra/terraform.tfvars` com seu `project_id`, `firebase_site_id` e `ssh_public_key` (conteúdo de `~/.ssh/marmitech-key.pub`).
3. Exporte os segredos via variáveis de ambiente (nunca salve senhas em arquivos versionados):

   ```bash
   export TF_VAR_db_password="sua-senha-forte-mysql"
   export TF_VAR_jwt_secret="sua-chave-secreta-jwt-minimo-32-chars"
   ```

---

## 5. Passo a Passo de Implantação (Na Ordem de Execução)

### Passo 1 — Inicializar e validar o Terraform

```bash
cd infra
terraform init
terraform fmt -check
terraform validate
```

### Passo 2 — Criar APIs e Artifact Registry (bootstrap da imagem)

Como o Cloud Run referencia a imagem no Artifact Registry, habilite as APIs e crie o repositório primeiro:

```bash
terraform apply -target=google_project_service.enabled_apis -target=google_artifact_registry_repository.repo
```

### Passo 3 — Build e push da imagem do Backend (Spring Boot)

Na raiz do repositório:

```bash
gcloud auth configure-docker southamerica-east1-docker.pkg.dev
docker build -t southamerica-east1-docker.pkg.dev/<PROJECT_ID>/marmitech-repo/marmitech-api:latest .
docker push southamerica-east1-docker.pkg.dev/<PROJECT_ID>/marmitech-repo/marmitech-api:latest
```

### Passo 4 — Provisionar toda a infraestrutura

```bash
cd infra
terraform plan
terraform apply
```

Ao final, confirme os valores gerados:

```bash
terraform output
```

### Passo 5 — Build e deploy do Frontend (Angular + Firebase Hosting)

```bash
cd marmitech-web
npm install
npm run build -- --configuration production
firebase deploy --only hosting --project <PROJECT_ID>
```

### Passo 6 — Gerar cópia inicial de backup no Cloud SQL (B6)

```bash
gcloud sql backups create --instance=marmitech-mysql --project=<PROJECT_ID>
gcloud sql backups list --instance=marmitech-mysql --project=<PROJECT_ID>
```

---

## 6. Comandos de Verificação e Acesso

- **Conectar na VM privada via IAP (Cloud Shell / terminal com `gcloud`):**

  ```bash
  gcloud compute ssh marmitech-vm-privada --zone=southamerica-east1-a --tunnel-through-iap
  ```

- **Testar recusa de autenticação por senha (S1):**

  ```bash
  ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password marmitech@<IP_PRIVADO>
  ```

- **Testar saída pelo IP do Cloud NAT dentro da VM privada (D4):**

  ```bash
  curl -s https://ifconfig.me
  ```

- **Análise automatizada de IaC e segredos (S7):**

  ```bash
  trivy config infra/
  gitleaks detect --source .
  ```

---

## 7. Destruição do Ambiente (`destroy`)

Ao encerrar os testes e em até **24 horas após a apresentação**, remova todos os recursos para evitar cobranças:

```bash
cd infra
terraform destroy
```

Verifique no console da GCP se não restaram gateways NAT, IPs públicos estáticos, discos ou instâncias Cloud SQL ativas.

---

## 8. Documentação Complementar

- [Arquitetura Base (Entrega 1)](docs/arquitetura.md)
- [ADRs (`docs/adr/`)](docs/adr/)
- [Errata (`docs/errata.md`)](docs/errata.md)
- [Segurança (`docs/seguranca.md`)](docs/seguranca.md)
- [Alta Disponibilidade Projetada (`docs/alta-disponibilidade.md`)](docs/alta-disponibilidade.md)
- [Plano de Backup (`docs/backup.md`)](docs/backup.md)
- [Declaração de Uso de IA (`IA.md`)](IA.md)
