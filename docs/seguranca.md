# Segurança da Infraestrutura (Parte B)

Este documento registra a implementação dos controles obrigatórios de segurança (**S1 a S8**), o tratamento dos achados de ferramentas automatizadas de análise e a análise de ameaças específicas da arquitetura **Marmitech** na Google Cloud Platform (GCP).

---

## 1. Controles de Segurança Implementados (S1 a S8)

| # | Controle | Implementação no Projeto | Onde Verificar |
| :--- | :--- | :--- | :--- |
| **S1** | **Endurecimento do SSH** | `metadata_startup_script` na VM privada (`e2-micro`) configura `PasswordAuthentication no`, `KbdInteractiveAuthentication no` e `PermitRootLogin no` em `/etc/ssh/sshd_config` e `/etc/ssh/sshd_config.d/99-hardening.conf`, reiniciando o serviço `ssh`/`sshd`. Acesso permitido apenas por chave pública via `metadata.ssh-keys`. | `infra/compute.tf` e teste `ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password` |
| **S2** | **Saída restrita (Egress)** | Como o egress padrão na GCP é aberto, foram criadas regras explícitas em `infra/security.tf`: `fw-allow-egress-web-dns` (TCP `80, 443, 53` e UDP `53`), `fw-allow-egress-mysql-internal` (TCP `3306` apenas para a VPC e peering do Cloud SQL) e `fw-deny-all-egress` (prioridade `65534` bloqueando todo o restante). | `infra/security.tf` |
| **S3** | **HTTPS** | O frontend no **Firebase Hosting** atende exclusivamente via HTTPS gerenciado com certificado TLS válido, encaminhando chamadas de API por meio de `rewrites` para o **Cloud Run** (que também expõe endpoint HTTPS gerenciado). | `infra/compute.tf` e `curl -vk https://<APP_URL>` |
| **S4** | **Gestão de segredos** | Senha do banco (`db_password`) e chave JWT (`jwt_secret`) declaradas como variáveis Terraform `sensitive = true`, fornecidas via `TF_VAR_*` no ambiente e armazenadas no **Google Secret Manager**, consumidas pelo Cloud Run via `secret_key_ref`. Nenhuma credencial ou `.tfvars` real é versionada no Git (`.gitignore` atualizado). | `infra/variables.tf`, `infra/security.tf`, `infra/compute.tf` e `.gitignore` |
| **S5** | **Menor privilégio para instâncias** | Criadas Service Accounts dedicadas sem chaves gravadas em disco: `marmitech-vm-sa` (apenas `roles/logging.logWriter`) e `marmitech-run-sa` (apenas `roles/cloudsql.client` e `roles/secretmanager.secretAccessor` restrito aos dois segredos da aplicação). | `infra/security.tf` |
| **S6** | **Criptografia em repouso** | Declarada explicitamente via **Cloud KMS (CMEK)** com `google_kms_key_ring` e `google_kms_crypto_key` (`marmitech-disk-key`, rotação de 90 dias), vinculada em código ao `boot_disk.kms_key_self_link` da VM privada e ao `encryption_key_name` do Cloud SQL (e herdada pelos backups automáticos). | `infra/security.tf` e `infra/compute.tf` |
| **S7** | **Análise automatizada** | Análise estática da IaC com **Trivy** (`trivy config infra/`) ou **Checkov** (`checkov -d infra/`) e varredura de segredos no histórico Git com **Gitleaks** (`gitleaks detect --source .`), com relatórios salvos em `docs/evidencias/`. | `docs/evidencias/` e Seção 2 abaixo |
| **S8** | **Proteção da conta** | Autenticação Multifator (MFA / Verificação em duas etapas) habilitada na conta Google/GCP utilizada pelo grupo para provisionamento. | Print em `docs/evidencias/` (sem dados sensíveis) |

---

## 2. Tratamento dos Achados (Análise Automatizada — S7)

> **Instrução para o grupo:** "Execute `trivy config infra/` (ou `checkov -d infra/`) e `gitleaks detect --source .`, salve os relatórios completos em `docs/evidencias/` e registre abaixo **todos os achados de severidade Alta ou Crítica** (além dos relevantes de severidade Média) com a decisão tomada (`Corrigido` ou `Aceito` + justificativa). Nenhum achado Alto ou Crítico pode ficar sem decisão."

### 2.1 Comandos executados

```bash
trivy config infra/ > docs/evidencias/trivy-infra.txt
gitleaks detect --source . --report-path docs/evidencias/gitleaks-report.json
```

### 2.2 Registro de decisões sobre os achados

| Ferramenta | ID / Achado | Severidade | Recurso / Local | Decisão | Justificativa |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Trivy** | `GCP-0015` — *Database instance does not require TLS for all connections* | `HIGH` | `infra/compute.tf` (`google_sql_database_instance.mysql`) | **Aceito** | O Cloud SQL possui IP público desabilitado (`ipv4_enabled = false`) e recebe conexões exclusivamente pela rede privada da VPC via Peering / Serverless VPC Access Connector, além de criptografia em repouso via CMEK (`marmitech-disk-key`). |
| **Trivy** | `GCP-0030`, `GCP-0036`, `GCP-0041`, `GCP-0045`, `GCP-0067` — *Project-level SSH keys, OS Login disabled, Shielded VM (vTPM, integrity, secure boot)* | `MEDIUM` | `infra/compute.tf` (`google_compute_instance.vm_privada`) | **Aceito** | VM privada de apoio (`e2-micro`) sem IP público, com acesso SSH restrito ao CIDR do IAP (`35.235.240.0/20`), chave pública explícita nos metadados e autenticação por senha/root desativada via script de inicialização (S1). |
| **Trivy** | `GCP-0076` — *Subnetwork does not have flow logs enabled* | `MEDIUM` | `infra/network.tf` (`subnet-public`, `subnet-private`, `subnet-vpc-connector`) | **Aceito** | VPC Flow Logs mantidos desabilitados para evitar custos adicionais de ingestão e armazenamento no Cloud Logging durante o período de testes acadêmicos. |
| **Gitleaks** | `private-key` — Chaves privadas efêmeras de VM local Vagrant/VirtualBox em commit histórico (`346da38a`) | `HIGH` | `marmitech-infra/.vagrant/machines/instancia-{1,3}/virtualbox/private_key` (histórico Git) | **Aceito** | Chaves locais descartáveis geradas pelo Vagrant/VirtualBox em ambiente de desenvolvimento antigo (4º/5º período), já removidas da árvore atual e bloqueadas no `.gitignore`. Nenhuma credencial real da GCP ou de produção foi exposta. |

---

## 3. Análise de Ameaças (Mínimo 5 Ameaças Concretas)

| # | Ameaça Concreta | Ativo Afetado | Controles Aplicados | Risco Residual |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Tentativa de invasão por força bruta ou enumeração SSH na VM privada** | VM Privada (`marmitech-vm-privada`, `10.20.10.15`) | Sem IP público associado; regra `fw-allow-ssh-iap` restrita ao CIDR do IAP (`35.235.240.0/20`, nunca `0.0.0.0/0`); autenticação por senha e login `root` desativados via `metadata_startup_script` (S1). | Comprometimento da chave SSH privada de algum integrante ou comprometimento de conta IAM com permissão IAP. |
| **2** | **Vazamento de credenciais do banco ou chave JWT no repositório ou variáveis** | Cloud SQL (`marmitech-mysql`) e autenticação da API (`marmitech-api`) | Variáveis marcadas com `sensitive = true` fornecidas por `TF_VAR_*`, armazenadas no Secret Manager (S4), `.gitignore` bloqueando `.tfstate`, `.tfvars` e chaves, além de varredura com Gitleaks (S7). | Exposição acidental das variáveis de ambiente na máquina local de um integrante durante o `apply` ou erro operacional ao commitar arquivo fora do padrão ignorado. |
| **3** | **Exfiltração de dados ou comunicação lateral a partir da VM privada comprometida** | Sub-rede privada (`10.20.10.0/24`) e Cloud SQL (`3306`) | Regras explícitas de `EGRESS` bloqueando portas não autorizadas (`fw-deny-all-egress`, S2), permitindo apenas HTTP/HTTPS/DNS e `3306` interno; Service Account da VM limitada a `roles/logging.logWriter` (S5). | Tráfego malicioso encapsulado na porta `443` (HTTPS) saindo pelo Cloud NAT, pois o firewall L3/L4 permite saída HTTPS para atualizações de pacotes. |
| **4** | **Requisições não autorizadas ou abuso de endpoints sem autenticação / CORS permissivo** | Cloud Run (`marmitech-api`) e Firebase Hosting | Tráfego público servido via HTTPS (S3), validação de tokens JWT assinados com `JWT_SECRET` do Secret Manager e restrição de CORS no `SecurityConfig.java` para a origem do Firebase Hosting. | Ataques de força bruta na rota de login ou envio direto de requisições à URL do Cloud Run contornando o Firebase Hosting (já que o invocador é `allUsers`). |
| **5** | **Acesso indevido a backups ou discos físicos / snapshots do banco de dados** | Disco da VM privada e instância Cloud SQL (`marmitech-mysql`) | Banco sem IP público (`ipv4_enabled = false`), acessível apenas via VPC Peering / conector (`10.20.100.0/28`), e criptografia explícita em repouso com Cloud KMS / CMEK (`marmitech-disk-key`, S6). | Uso indevido por conta administrativa GCP com papel amplo (`Owner`/`Editor`) caso haja falha na proteção da conta (mitigado por MFA — S8). |

---

## 4. Evidências de Verificação (S1, S3, S7, S8)

Salve em `docs/evidencias/` e referencie aqui após os testes:

- `docs/evidencias/mfa-gcp.png` — Captura de tela do MFA ativo na conta GCP (sem dados sensíveis).
- `docs/evidencias/trivy-infra.txt` — Relatório completo da análise da IaC.
- `docs/evidencias/gitleaks-report.json` — Relatório completo da verificação de segredos no histórico Git.
- `docs/evidencias/ssh-recusa-senha.png` — Saída de `ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password ...` exibindo `Permission denied (publickey)`.
- `docs/evidencias/https-tls.png` — Saída de `curl -vk https://<APP_URL>` comprovando TLS ativo.
