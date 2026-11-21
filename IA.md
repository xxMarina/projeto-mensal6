# Declaração de Uso de Inteligência Artificial

Este documento registra de forma transparente a utilização de ferramentas de Inteligência Artificial durante a elaboração da **Entrega 1** e da **Entrega 2** do Projeto Integrador.

---

## Parte I — Entrega 1: Projeto de Arquitetura e Decisões de Infraestrutura

### 1. Ferramentas Utilizadas

| Ferramenta / Modelo | Empresa / Plataforma | Finalidade Principal |
| :--- | :--- | :--- |
| **Gemini 3.8 Flash** | Google DeepMind | Auxílio na calculadora GCP, geração da documentação técnica e auxílio na interpretação dos requisitos do trabalho. |

### 2. Partes do Trabalho em que a IA foi Empregada

1. **Interpretação e Planejamento dos Requisitos:** Apoio no mapeamento de conceitos da nuvem (VPC, sub-redes, NAT, regras de segurança e conectividade de banco de dados) para os serviços equivalentes na Google Cloud Platform (GCP).
2. **Estimativa de Custos (Seção 5.9):** Suporte na identificação dos SKUs na Google Cloud Pricing Calculator (`e2-micro`, Cloud Run, Cloud SQL for MySQL `db-f1-micro`, Cloud NAT e IP Address) e modelagem da tabela comparativa entre os cenários A e B.

### 3. Verificações e Correções Humanas (Entrega 1)

- A equipe acessou a Google Cloud Pricing Calculator para cotar os valores reais em `southamerica-east1` (São Paulo), corrigindo itens ociosos e gerando o link público e exportação oficial.
- Os dados técnicos e o dimensionamento foram ajustados manualmente para refletir a pilha real da Marmitech (Angular, Spring Boot 3 / Java 17 e MySQL 8.0).

---

## Parte II — Entrega 2: Implantação, Segurança, Alta Disponibilidade e Backup

### 1. Ferramentas Utilizadas

| Ferramenta / Modelo | Empresa / Plataforma | Finalidade Principal |
| :--- | :--- | :--- |
| **Gemini 4 Hydrogen** | Google DeepMind | Estruturação do código Terraform (`infra/`), redação dos novos ADRs, criação da errata e estruturação dos documentos técnicos em `docs/`. |

### 2. Partes do Trabalho em que a IA foi Empregada

1. **Infraestrutura como Código (`infra/`):** Conversão do rascunho de referência em arquivos organizados (`versions.tf`, `providers.tf`, `variables.tf`, `network.tf`, `security.tf`, `compute.tf`, `outputs.tf`, `terraform.tfvars.example`) e adequação às regras da Seção 7.2.
2. **ADRs e Errata (`docs/adr/` e `docs/errata.md`):** Marcação de substituição do ADR-002, criação dos ADRs 004, 005 e 006 e mapeamento das divergências entre a Entrega 1 e a implantação.
3. **Documentação Técnica (`docs/seguranca.md`, `docs/alta-disponibilidade.md`, `docs/backup.md`, `README.md`):** Estruturação dos roteiros, matrizes de ameaças, diagramas Mermaid e tabelas comparativas.

### 3. Verificações, Correções e Contribuições Humanas da Equipe (Entrega 2)

- **Validação de IaC:** Execução de `terraform init`, `terraform fmt -check` e `terraform validate`, além da revisão manual de variáveis, CIDRs, regras de `EGRESS` (porta `3306` e bloqueio padrão) e criação do segredo `jwt_secret` que faltava no rascunho inicial.
- **Ajustes na Aplicação e Execução em Nuvem:** Revisão e correção do código do frontend/backend (HTTPS, CORS, `rewrites` do Firebase Hosting e `JWT_SECRET`), provisionamento real na conta GCP com `terraform apply` e execução das demonstrações D1–D6.
- **Análises, Cálculos Oficiais e Evidências:** Execução local das ferramentas de análise (`trivy` e `gitleaks`), decisão humana sobre cada achado, desenho dos diagramas editáveis (`PROJETO INTEGRADOR HA.vsdx`), cotação oficial na Google Cloud Pricing Calculator (HA e planilha de 12 meses GFS), captura de evidências (MFA, prints e vídeo de contingência) e execução de `terraform destroy` após a apresentação.
- **Revisão e Atualização dos Documentos (`.md`):** Conferência e ajuste manual de `README.md`, `docs/seguranca.md`, `docs/alta-disponibilidade.md`, `docs/backup.md`, `docs/errata.md`, ADRs (`docs/adr/`) e `IA.md` para refletir fielmente os recursos, comandos e evidências reais da entrega.
