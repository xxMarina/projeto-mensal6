# ADR-003 - Localização do banco de dados

No contexto da arquitetura de persistência de dados da aplicação,
diante da necessidade de garantir rotinas de backup eficientes, atualizações de segurança e alta disponibilidade,
decidimos utilizar um serviço de banco de dados relacional totalmente gerenciado (Google Cloud SQL),
e descartamos a instalação manual, e gerenciada por nós, do banco de dados em uma VM alocada na sub-rede privada,
para focar o esforço da equipe no desenvolvimento da aplicação em vez de na administração e manutenção de infraestrutura de dados,
aceitando que o custo mensal do serviço gerenciado é consideravelmente maior do que rodar o serviço em uma VM de uso geral e que perdemos o controle direto sobre o sistema do banco.