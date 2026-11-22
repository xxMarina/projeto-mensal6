# Plano de Backup (Parte D)

Este documento define o plano completo de backup da **Marmitech** (**B1 a B7**), separando a **Política Conservadora (GFS)** recomendada para operação em produção da **Política Mínima** efetivamente configurada via Terraform na Entrega 2.

---

## B1 — Inventário de Ativos

| Ativo | Precisa de Backup? | Justificativa |
| :--- | :---: | :--- |
| **Banco de dados MySQL (`marmitech` no Cloud SQL)** | **Sim** | Contém todos os dados transacionais e cadastrais (clientes, cardápio, pedidos, histórico). O Terraform recria a instância vazia, mas não recria os registros. |
| **State do Terraform (`terraform.tfstate`)** | **Sim** | Registra o mapeamento entre o código HCL e os recursos reais na GCP; sua perda exige importação manual ou dificulta o `destroy`. *(Armazenado fora do Git por segurança).* |
| **Variáveis e segredos (`terraform.tfvars`, `TF_VAR_*`, segredos no Secret Manager)** | **Sim** | Contêm parâmetros de ambiente e segredos (`db_password`, `jwt_secret`) que não ficam no repositório Git; guardados em cofre seguro da equipe. |
| **Infraestrutura VPC, Sub-redes, Firewall, NAT, Cloud Run, VM** | **Não** | 100% reproduzíveis via código declarativo em `infra/` (`terraform apply`). |
| **Código-fonte (Backend Java, Frontend Angular) e Imagens Docker** | **Não** | Versionados no repositório Git; as imagens podem ser reconstruídas a partir do `Dockerfile` e enviadas ao Artifact Registry. |
| **Sistema operacional e pacotes da VM privada** | **Não** | A VM é apenas de apoio/diagnóstico sem dados persistentes; sua configuração e endurecimento SSH (S1) são reproduzidos via `metadata_startup_script`. |

---

## B2 — RPO e RTO Justificados

| Métrica | Meta Definida (Operação Real) | Justificativa pelo Uso da Aplicação |
| :--- | :---: | :--- |
| **RPO (Recovery Point Objective)** | **24 horas** *(ou minutos com `binary_log_enabled` / PITR)* | A Marmitech processa ~1.000 requisições/dia em horário comercial. Em um cenário de falha grave, o backup diário limita a perda máxima a 1 dia de operação, sendo possível reduzir o RPO para minutos usando *Point-in-Time Recovery* (logs binários do MySQL). |
| **RTO (Recovery Time Objective)** | **2 horas** | Como o restaurante utiliza o cardápio e a fila da cozinha durante o horário de atendimento (almoço), a restauração do dump/snapshot do Cloud SQL e eventual recriação da infraestrutura via Terraform precisa ocorrer dentro de uma janela máxima de 2 horas para não comprometer o turno seguinte. |

---

## B3 — Política Conservadora (Esquema Grandfather-Father-Son — GFS)

A política conservadora recomendada para produção combina backups automáticos do Cloud SQL com exportações lógicas (dumps SQL consistentes) gravadas em bucket dedicado no Cloud Storage sob prefixos por geração:

| Geração | Frequência | Momento de Promoção | Retenção | Mecanismo | Classe de Armazenamento (GCS) |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **Son (Filho)** | Diária (`03:00`) | — | **7 dias** | Backup automático gerenciado do Cloud SQL + logs binários (PITR) | Gerenciado pelo Cloud SQL |
| **Father (Pai)** | Semanal | Cópia do **domingo** promovida para `semanal/` | **4 semanas** (4 cópias) | Exportação lógica (`Cloud SQL Export` / `mysqldump` consistente) para GCS | `Standard` |
| **Grandfather (Avô)** | Mensal | Cópia do **último dia do mês** promovida para `mensal/` | **12 meses** (12 cópias) | Exportação lógica (`Cloud SQL Export` / `mysqldump`) para GCS com regra de ciclo de vida | `Nearline` ou `Coldline` *(atenção à duração mínima de 30/90 dias e taxa de recuperação)* |

---

## B4 — Local de Armazenamento, Criptografia e Acesso

- **Local:** Os backups das gerações Father e Grandfather são armazenados em um **bucket no Google Cloud Storage (`gs://marmitech-backups-...`)**, fisicamente **fora da instância do Cloud SQL e da VM**, preferencialmente com replicação **Multi-Region (`us` / `southamerica`)** ou em região distinta de `southamerica-east1` para resistir a falhas regionais.
- **Criptografia (S6):** O bucket utiliza criptografia explícita com chave gerenciada no Cloud KMS (CMEK). Os backups automáticos do Cloud SQL herdam automaticamente a chave CMEK configurada na instância (`encryption_key_name = google_kms_crypto_key.disk_key.id`).
- **Acesso Restrito (S5):** Apenas a Service Account dedicada da rotina de backup possui permissão `roles/storage.objectCreator` no prefixo apropriado, sem permissão de exclusão/sobrescrita para evitar que um invasor que comprometa a instância da aplicação apague backups antigos (proteção reforçada com *Bucket Lock / Retention Policy* e versionamento).

---

## B5 — Responsabilidade Compartilhada

| Ativo / Camada | O que o Provedor (GCP) Garante | O que é Responsabilidade do Grupo / Equipe |
| :--- | :--- | :--- |
| **Cloud SQL (Backups Automáticos)** | Disponibilidade do serviço de backup, armazenamento redundante, execução da agenda e criptografia física/CMEK. | Configurar `backup_configuration`, definir janela e retenção, monitorar falhas e executar testes periódicos de restauração. |
| **Cloud Storage (Dumps GFS)** | Durabilidade dos objetos (99,999999999%), execução assíncrona das regras de ciclo de vida (*Lifecycle*) e criptografia. | Configurar a rotina de exportação lógica, regras de ciclo de vida, políticas IAM de menor privilégio (S5) e validar a integridade dos dumps. |
| **Código Terraform e Segredos** | — | Versionamento do código no Git (sem segredos) e guarda segura do `terraform.tfstate` e `TF_VAR_*`. |

---

## B6 — Política Mínima Configurada na Entrega 2

Para exercitar os mecanismos de backup com custo próximo de zero durante a disciplina, foi configurada apenas a geração **Son** no próprio Cloud SQL via Terraform (`infra/compute.tf`):

- **Configuração por código (`infra/compute.tf`):**
  - `backup_configuration.enabled = true`
  - `start_time = "03:00"`
  - `binary_log_enabled = true`
  - `transaction_log_retention_days = 2`
  - `backup_retention_settings { retained_backups = 2, retention_unit = "COUNT" }`
- **Criptografia (S6):** A instância `google_sql_database_instance.mysql` declara explicitamente `encryption_key_name = google_kms_crypto_key.disk_key.id`. Na GCP, backups automáticos do Cloud SQL herdam a criptografia CMEK da instância de origem.
- **Comportamento de expiração assíncrona na GCP:** Conforme documentação oficial do Google Cloud, a exclusão/expiração de backups antigos que excedem `retained_backups` e a limpeza de arquivos expirados por regras de ciclo de vida ocorrem de forma **assíncrona** (em segundo plano), podendo não ocorrer exatamente no minuto em que o limite é atingido.
- **Existência de cópia:** Para validação e demonstração D6, é gerada ao menos 1 cópia sob demanda via `gcloud sql backups create --instance=marmitech-mysql` (verificável com `gcloud sql backups list --instance=marmitech-mysql`).
- **O que a política mínima NÃO protege frente à política conservadora (GFS):**
  1. **Erros descobertos após 2 dias:** Qualquer exclusão acidental de tabela ou corrupção lógica identificada depois de 48 horas não pode ser revertida.
  2. **Histórico semanal/mensal e auditoria:** Não há retenção de 4 semanas (Father) nem de 12 meses (Grandfather) para restauração histórica ou conformidade.
  3. **Isolamento fora do serviço Cloud SQL:** Se a instância inteira do Cloud SQL for excluída (`terraform destroy` ou remoção acidental sem proteção), os backups automáticos vinculados à instância também são removidos junto com ela — ao contrário dos dumps exportados para um bucket GCS independente.

---

## B7 — Custo Anual (12 Meses) da Política Conservadora GFS e Política Mínima

### 7.1 Custo da Política Mínima (Período do Trabalho)

- Armazenamento de até 2 backups pequenos (`< 1 GB`) + logs binários no Cloud SQL durante ~25h de testes: **custo próximo de zero (< R$ 0,50)**, coberto praticamente pela franquia básica de armazenamento de backup equivalente ao tamanho provisionado do disco no Cloud SQL.

### 7.2 Premissas da Simulação Anual GFS (12 Meses)

- **Link oficial na Google Cloud Pricing Calculator:** [Backup and DR for Cloud SQL (GFS)](https://cloud.google.com/products/calculator?dl=CjhDaVF3WlRjeFlqYzRaUzFtTkdWakxUUXlNVGd0WW1Vd1ppMHpOVGc1T0RNM09ERXhZalFRQVE9PRA7GiQ4RDI1MDAzNy1GMjY4LTQyNUUtODY0QS1EN0ExOEYxMUM3REU)
- **Serviço cotado:** **Backup and DR for Cloud SQL (Backup Vault)** em região distinta (`us-central1`, fora da região `southamerica-east1` da instância).
- **Volume inicial dos dados do banco:** `5,0 GiB` (taxa média de alteração diária de `5%`).
- **Acúmulo de cópias:**
  - **Son (Diária):** estabiliza em `7` cópias a partir do Mês 1.
  - **Father (Semanal):** estabiliza em `4` cópias a partir do Mês 1.
  - **Grandfather (Mensal):** acumula `+1` cópia por mês (`1` no Mês 1 até `12` no Mês 12).
- **Valor na calculadora:** **R$ 10,55 / mês** (**R$ 126,59 / ano**) já considerando a retenção completa GFS (7 dias, 4 semanas, 12 meses) no Backup Vault.

### 7.3 Evolução Mês a Mês (Mês 1 ao Mês 12)

| Mês | Volume da Aplicação | Cópias Retidas (Son + Father + Grandfather) | Volume em Backup (Estimado) | Custo Mensal Estimado |
| :---: | :---: | :---: | :---: | :---: |
| **1** | 5,00 GiB | 7 + 4 + 1 = **12 cópias** | ~6,00 GiB | R$ 6,86 |
| **2** | 5,25 GiB | 7 + 4 + 2 = **13 cópias** | ~7,00 GiB | R$ 7,43 |
| **3** | 5,50 GiB | 7 + 4 + 3 = **14 cópias** | ~8,00 GiB | R$ 8,00 |
| **4** | 5,75 GiB | 7 + 4 + 4 = **15 cópias** | ~9,00 GiB | R$ 8,58 |
| **5** | 6,00 GiB | 7 + 4 + 5 = **16 cópias** | ~10,00 GiB | R$ 9,15 |
| **6** | 6,25 GiB | 7 + 4 + 6 = **17 cópias** | ~11,00 GiB | R$ 9,72 |
| **7** | 6,50 GiB | 7 + 4 + 7 = **18 cópias** | ~12,00 GiB | R$ 10,29 |
| **8** | 6,75 GiB | 7 + 4 + 8 = **19 cópias** | ~13,00 GiB | R$ 10,86 |
| **9** | 7,00 GiB | 7 + 4 + 9 = **20 cópias** | ~14,00 GiB | R$ 11,43 |
| **10** | 7,25 GiB | 7 + 4 + 10 = **21 cópias** | ~15,00 GiB | R$ 12,00 |
| **11** | 7,50 GiB | 7 + 4 + 11 = **22 cópias** | ~16,00 GiB | R$ 12,58 |
| **12** | 7,75 GiB | 7 + 4 + 12 = **23 cópias** | ~17,00 GiB | R$ 13,15 |
| **Total no Ano** | — | — | — | **R$ 126,59** *(na média anualizada da calculadora)* |

### 7.4 Parâmetro de Maior Impacto e Trade-off

- **Qual parâmetro mais influencia o custo anual:** A **retenção da geração Grandfather (12 meses)** (combinada com o crescimento do volume de dados), pois é a única geração que continua acumulando novas cópias ao longo de todos os 12 meses (chegando a mais da metade de todas as cópias retidas no Mês 12), enquanto Son e Father estabilizam já no primeiro mês.
- **O que se perderia ao reduzi-lo:** Ao reduzir a retenção Grandfather (por exemplo, de 12 para 3 ou 6 meses), perde-se a capacidade de restaurar estados históricos antigos para auditoria financeira/fiscal, investigação de fraudes ou recuperação de exclusões silenciosas descobertas meses depois.
