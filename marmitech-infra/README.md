Provisionamento 100% automático da aplicação Marmitech usando Vagrant + Ansible. Um único comando sobe a VM, compila o projeto e inicia banco de dados + frontend + backend funcionais.

Como usar  
1. Subir do zero  
cd marmitech-infra/  
 vagrant up  
   
Isso vai:  
1. Baixar a imagem Ubuntu 22.04 (apenas na primeira vez)  
2. Criar e configurar a VM no VirtualBox  
3. Rodar o Ansible automaticamente, que:  
- Instala Java 17, Maven, Node 20, MySQL  
- Compila o backend com Maven  
- Faz build de produção do Angular  
- Cria os serviços systemd e os inicia  
Acesse no navegador:  
- Frontend → http://localhost:4200  
- Backend  → http://localhost:8080  
2. Reprovisionar (idempotente)  
Caso você já tenha subido uma VM e quer reaplicar as configurações (ex: após alterar o código):  
vagrant provision  
   
3. Ver logs dos serviços dentro da VM  
vagrant ssh  
 sudo journalctl -u marmitech-backend -f    # logs do backend  
 sudo journalctl -u marmitech-frontend -f   # logs do frontend  
   
4. Derrubar a VM  
vagrant halt      # desliga, mantém arquivos  
 vagrant destroy   # apaga tudo  
   
Variáveis configuráveis (group_vars/marmitech_vm.ym)  
backend_port:    8080  
 frontend_port:   4200  
 db_name:         "marmitech_db"  
 db_user:         "marmitech_user"  
 db_password:     "marmitech_pass"    
 java_version:    "17"  
 node_version:    "20"  
   
   
 Fluxo de provisionamento (Vagrant up):  
   1. VirtualBox cria a VM  
   2. Vagrant monta /vagrant_src (código do host)  
   3. Ansible SSH → VM:  
        a. Instala JDK 17, Maven, Node 20, MySQL  
        b. mvn clean package (compila o JAR)  
        c. ng build --configuration production  
        d. Copia artefatos para /opt/marmitech/  
        e. Cria/atualiza serviços systemd  
        f. Inicia backend → aguarda porta 8080  
        g. Inicia frontend → aguarda porta 4200  

Primeiro Acesso: Criar Usuário
Como o banco MySQL nasce zerado e isolado em cada VM, cadastre o primeiro usuário executando o comando no terminal (ajuste a porta 8080 caso esteja em uma instância paralela, ex: 8082):

curl -i -X POST http://localhost:8080/api/usuario/save \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "Administrador",
    "email": "admin@marmitech.com",
    "senha": "123456",
    "cargo": "ADMIN"
  }'

Login: admin@marmitech.com
Senha: 123456


Por que Vagrant + Ansible?  

| Critério | Escolha | Justificativa |   
| Gerenciamento de VM | Vagrant | Abstrai VirtualBox; Vagrantfile versionável; vagrant up é um único comando |   
| Configuração interna | Ansible | Sem agente na VM; YAML legível; idempotente por padrão; integra nativamente com Vagrant |   
