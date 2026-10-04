# ADR-001: Estratégia de acesso administrativo às instâncias

No contexto da configuração de acesso administrativo seguro aos recursos da nuvem,
diante da restrição de não expor portas SSH na internet pública a fim de reduzir ataques,
decidimos utilizar a CLI gcloud do Google Cloud e IAM para gerenciar permissões de acesso,
e descartamos a criação de uma instância de Bastion Host ou a alocação de IPs públicos diretos nas instâncias,
para reduzir a superfície de ataque e eliminar as despesas vinculadas a uma VM intermediária de Bastion Host,
aceitando que o gerenciamento de acesso passa a depender exclusivamente do IAM da GCP e que não teremos um acesso interativo direto em SSH aos containers em execução.