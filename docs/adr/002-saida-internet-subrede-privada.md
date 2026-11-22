# ADR-002 - Saída para a internet da sub-rede privada

**Status:** Substituída pelo [ADR-004](004-cloud-nat-subrede-privada.md) na Entrega 2 (adoção obrigatória de Cloud NAT gerenciado).

No contexto de uma arquitetura serverless onde o Cloud Run, atuando como uma API do backend, se comunica com o banco de dados Cloud SQL através de uma VPC própria,
diante da necessidade de reduzir os custos da infraestrutura,
decidimos configurar a sub-rede privada com ausência de saída para a internet,
e descartamos o uso de um NAT gerenciado (Cloud NAT) ou de um NAT em instância (uma VM dedicada),
para que possamos eliminar os custos fixos mensais e as taxas de processamento de dados do Cloud NAT, utilizando a VPC exclusivamente como uma ponte de trânsito interna e segura entre o Cloud Run e o banco de dados,
aceitando que a VPC se torna um ambiente isolado, fazendo com que recursos dentro da VPC não tenham acesso nativo à internet, e que o Cloud Run dependerá exclusivamente do seu acesso inato à internet com IPs dinâmicos gerenciados pelo Google.
