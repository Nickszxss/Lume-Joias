# Backlog do Projeto — Sistema de Gerenciamento de Estoque (SGE) Lume Joias

## Arquitetura Serverless
- [x] Front-end SPA (HTML + CSS + JavaScript) hospedado no GitHub Pages
- [x] Conexão direta client-side com Supabase (PostgreSQL / Supabase Auth)
- [x] Eliminação do backend Java/Spring Boot e servidor local

## Autenticação e Segurança
- [x] Login exclusivo via E-mail + Senha (sem exigência de campo de Nome no login)
- [x] Suporte a BCrypt e Supabase Auth (`signInWithPassword`)
- [x] Cadastro de contas ativas: Anderson, Robson, Isabella, Manuella, Nicoly Funcionária (`nicoly.func@empresa.com`) e Nicoly Gerente (`nicoly.grt@empresa.com`)
- [x] Validação de permissões e isolamento por filial via RLS

## Gestão de Produtos, Estoque e Operações
- [x] Cadastro e listagem de produtos no Supabase
- [x] Ajuste manual de estoque (entrada/saída)
- [x] Alertas visuais para estoque baixo/zerado
- [x] Solicitação e conclusão de transferências entre filiais
- [x] Pedidos de compra (1:N relacional `pedidos_compra` + `itens_pedido_compra`)
- [x] Histórico auditável de movimentações
