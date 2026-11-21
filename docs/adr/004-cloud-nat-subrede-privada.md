# ADR-004: Saída para a internet da sub-rede privada via Cloud NAT

**Status:** Substitui o [ADR-002](002-saida-internet-subrede-privada.md)

No contexto da implantação da infraestrutura da aplicação Marmitech na GCP com uma sub-rede privada (`subnet-private`, `10.20.10.0/24`) contendo a VM privada (`e2-micro` sem IP público) e conectividade privada ao Cloud SQL,
diante da obrigatoriedade de fornecer saída controlada para a internet na Entrega 2 (requisitos R4 e D4) e da necessidade de a VM privada baixar atualizações de sistema e validar a conectividade de saída sem expor IP público direto,
decidimos provisionar um Cloud NAT gerenciado associado a um Cloud Router e a um endereço IP externo estático (`MANUAL_ONLY`),
e descartamos a ausência total de saída para a internet (decisão anterior do ADR-002) e a configuração de uma instância Compute Engine dedicada fazendo NAT manual com `iptables`,
para garantir saída segura e gerenciada da sub-rede privada com IP público estático previsível nos outputs do Terraform e sem sobrecarga operacional de manter uma VM de roteamento,
aceitando que o Cloud NAT e o endereço IP público estático reservado geram cobrança fixa por hora mesmo quando não há tráfego de rede (elevando significativamente o custo do Cenário B de testes), além da cobrança por volume de dados processados, o que exige a destruição do ambiente com `terraform destroy` entre as sessões de teste.
