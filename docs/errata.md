# Errata — Divergências entre a Entrega 1 e a Implantação (Entrega 2)

Este documento registra todas as divergências entre o projeto arquitetural documentado na Entrega 1 (`docs/arquitetura.md` e `docs/adr/001` a `003`) e o ambiente efetivamente implementado na Entrega 2 (`infra/` e ajustes na aplicação).

## 1. Substituição do ADR-002 pelo ADR-004 (Adoção do Cloud NAT)

- **O que estava previsto na Entrega 1:** O [ADR-002](adr/002-saida-internet-subrede-privada.md) definia a sub-rede privada sem saída para a internet para evitar os custos fixos e de processamento do Cloud NAT. Entretanto, na mesma entrega, a Seção 5.2 e a Seção 5.4 de `docs/arquitetura.md` já ilustravam o fluxo de saída via Cloud NAT.
- **O que foi implantado na Entrega 2:** O [ADR-002](adr/002-saida-internet-subrede-privada.md) recebeu status **Substituída** e foi criado o [ADR-004](adr/004-cloud-nat-subrede-privada.md), implementando em `infra/network.tf` o `google_compute_router`, `google_compute_address` (IP externo estático) e `google_compute_router_nat` com alocação `MANUAL_ONLY`.
- **Motivo:** Cumprir a obrigatoriedade do NAT gerenciado com IP público nos outputs (requisitos R4 e D4 da Entrega 2) e permitir que a VM privada (`10.20.10.15`) acesse repositórios externos para atualizações e validação de saída (`curl -s https://ifconfig.me`).

## 2. Endurecimento de Regras de Firewall (`EGRESS`) e Criptografia Explícita (Cloud KMS)

- **O que estava previsto na Entrega 1:** A matriz de segurança da Seção 5.5 de `docs/arquitetura.md` listava apenas uma regra genérica de saída (`fw-allow-egress-default`), não explicitava bloqueio padrão de saída (no GCP o egress implícito é aberto) e utilizava apenas criptografia padrão gerenciada pelo provedor sem declaração de Cloud KMS. Além disso, a regra `fw-allow-mysql-internal` usava origem ampla (`10.20.0.0/16`) e referência genérica à tag `fw-private`.
- **O que foi implantado na Entrega 2:** Em `infra/security.tf` foram implementadas:
  - Restrição de saída explícita (**S2**): `fw-allow-egress-web-dns` (TCP `80`, `443`, `53` e UDP `53`), `fw-allow-egress-mysql-internal` (TCP `3306` apenas para a faixa da VPC e do peering privado do Cloud SQL) e `fw-deny-all-egress` (prioridade `65534` negando todo o restante).
  - Tag de rede `ssh-iap` na VM privada para recebimento de SSH exclusivamente da faixa IAP (`35.235.240.0/20`, via variável `var.iap_cidr`).
  - Restrição da regra `fw-allow-mysql-internal` às sub-redes internas necessárias (`subnet-vpc-connector` e `subnet-private`).
  - Criptografia em repouso declarada explicitamente via **Cloud KMS (CMEK)** (`google_kms_key_ring` e `google_kms_crypto_key`) aplicada no disco da VM privada e na instância do Cloud SQL (**S6**).
- **Motivo:** Atender aos controles obrigatórios de segurança **S2** (saída restrita), **S5** (menor privilégio via Service Accounts dedicadas) e **S6** (criptografia em repouso explícita no código IaC).

## 3. Padronização do Nome do Banco de Dados e Nomenclatura de Recursos

- **O que estava previsto na Entrega 1:** O banco de dados local da aplicação usava o nome `marmitech_db` em `application.properties`, enquanto o rascunho de infraestrutura utilizava `marmitech`.
- **O que foi implantado na Entrega 2:** Em `infra/variables.tf` e `infra/compute.tf`, o nome do banco foi parametrizado na variável `db_name` (padrão `marmitech`) e injetado dinamicamente no Cloud Run por meio da variável de ambiente `SPRING_DATASOURCE_URL`.
- **Motivo:** Garantir consistência entre o provisionamento do Cloud SQL via Terraform e a string de conexão JDBC consumida pelo backend Spring Boot.

## 4. Ajustes na Aplicação para Execução em Nuvem (Frontend, Backend e Firebase Hosting)

- **O que estava previsto na Entrega 1:** A Entrega 1 assumia comunicação direta entre Firebase Hosting e Cloud Run sem detalhar incompatibilidades do código-fonte local.
- **O que foi ajustado na Entrega 2:**
  - **Roteamento e HTTPS:** O arquivo `marmitech-web/src/environments/environment.prod.ts` calculava a porta do backend dinamicamente (`currentPort + 3880`), o que falha em HTTPS (porta `443`), além de existir endpoints sem o prefixo `/api/` (`/historicoCompra` e `/pedidoItem`). Em `infra/compute.tf`, o `google_firebase_hosting_version` foi configurado com `rewrites` para `/api/**`, `/historicoCompra/**`, `/pedidoItem/**` e fallback SPA (`** -> /index.html`), além do ajuste da URL de produção e liberação de CORS em `SecurityConfig.java`.
  - **Gestão de segredos (S4):** O `JwtService.java` possuía chave JWT hardcoded como fallback; na nuvem o valor passou a ser fornecido exclusivamente via variável de ambiente `JWT_SECRET` injetada pelo Secret Manager no Cloud Run.
- **Motivo:** Garantir acesso funcional via HTTPS (S3), compatibilidade com todas as rotas do frontend e eliminação de segredos hardcoded no código (S4).

## 5. Issues Abertas pelo Professor após a Entrega 1

- **Situação verificada:** Não houve issues abertas pelo professor no repositório GitHub após a correção da Entrega 1, não havendo pendências externas a referenciar por número de issue.
