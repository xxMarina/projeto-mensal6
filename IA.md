# Declaração de Uso de Inteligência Artificial

Este documento registra de forma transparente a utilização de ferramentas de Inteligência Artificial durante a concepção, elaboração e validação da **Entrega 1: Projeto de Arquitetura e Decisões de Infraestrutura** do Projeto Integrador.

## 1. Ferramentas Utilizadas

| Ferramenta / Modelo | Empresa / Plataforma | Finalidade Principal |
| :--- | :--- | :--- |
| **Gemini 3.8 Flash** | Google DeepMind | Auxílio na calculadora GCP, geração da documentação técnica e auxilio na interpretação dos requisitos do trabalho. |

---

## 2. Partes do Trabalho em que a IA foi Empregada

1. **Interpretação e Planejamento dos Requisitos:**
   - Apoio no mapeamento de conceitos da nuvem (VPC, sub-redes, NAT, regras de segurança e conectividade de banco de dados) para os serviços equivalentes na Google Cloud Platform (GCP).
2. **Estimativa de Custos (Seção 5.9):**
   - Suporte na identificação correta dos SKUs na Google Cloud Pricing Calculator (Compute Engine `e2-micro`, Cloud Run, Cloud SQL for MySQL `db-f1-micro`, Cloud NAT e IP Address).
   - Simulação e modelagem da tabela comparativa entre o **Cenário A** (operação 24/7) e o **Cenário B** (janela de testes e apresentação).

## 3. Verificações, Correções e Contribuições Humanas da Equipe

A equipe assumiu responsabilidade integral sobre todos os artefatos gerados, realizando revisões críticas e ajustes técnicos manuais:

- **Ajuste e Verificação de Custos na Calculadora Oficial:** A equipe acessou pessoalmente a Google Cloud Pricing Calculator para cotar os valores na região `southamerica-east1` (São Paulo), identificando e corrigindo itens de cobrança ociosa (como IPs reservados sem uso) e gerando o link público e exportação oficial.
- **Adequação ao Sistema Marmitech:** Os dados técnicos e o dimensionamento foram ajustados para refletir com exatidão a pilha tecnológica real da Marmitech (Frontend Angular/Nginx, Backend Spring Boot 3 / Java 17 e MySQL 8.0).
