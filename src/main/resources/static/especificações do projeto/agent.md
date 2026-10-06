# AGENTS.md — Sistema de Gerenciamento de Estoque (5 Filiais) — Lume Joias

> Guia para agentes (IA ou humanos) trabalhando neste repositório.

---

## 1. Visão Geral do Projeto

Este é o sistema de gerenciamento de estoque **Lume Joias** para 5 filiais, com dois perfis de usuário: `gerente` e `funcionario` (`cargo` no Supabase PostgreSQL). O sistema controla produtos, ajustes de estoque (entrada e saída), transferências entre filiais, pedidos de compra manuais e relatórios com gráficos.

Atenção: este NÃO é um sistema de vendas. Leia a seção 6 (Escopo Negativo) antes de propor qualquer funcionalidade.

## 2. Stack e Arquitetura

A arquitetura oficial do projeto é **100% serverless / estática client-side**:

```text
Frontend:
HTML5 + CSS3 + JavaScript (Vanilla ES6+)

Hospedagem:
GitHub Pages

Backend / BaaS:
Supabase

Banco de Dados:
PostgreSQL / Supabase
```

Não existe dependência de servidor Java/Spring Boot. A comunicação entre a SPA (Single Page Application) e o banco de dados ocorre diretamente no cliente via Supabase JS SDK (`supabase.js` / `main.js`).

## 3. Regras de Negócio Críticas

1. **Autenticação:** O formulário de login exige apenas **E-mail + Senha**. Não exige campo de Nome do Usuário.
2. **Isolamento de Perfil Gerente:** O perfil `gerente` acessa as 5 filiais no Dashboard e possui permissão para criar Pedidos de Compra (`#btn-novo-pedido`).
3. **Isolamento de Perfil Funcionário:** O perfil `funcionario` acessa apenas os dados da sua filial atribuída (`filial_id`). Consultas no cliente são isoladas e a origem da transferência fica travada na sua filial.
4. **Criação de Pedidos:** Somente gerentes criam pedidos de compra (estrutura relacional 1:N entre `pedidos_compra` e `itens_pedido_compra`).
5. **Auditoria de Movimentação:** Toda alteração de estoque gera registro na tabela `movimentacoes` no Supabase com FK `usuario_id`, FK `filial_id` e data/hora.
6. **Transferências:** Transferência concluída altera saldo nas duas filiais e gera 2 movimentações no histórico (uma saída na origem e uma entrada no destino).
7. **Sem Vendas/Preços:** Ajustes são do tipo `entrada` ou `saida`. Não existem módulos de venda ou campo de preço de produtos.

## 4. Escopo Negativo (NÃO implementar)

O sistema NÃO possui:
- Backend Java/Spring Boot ou servidores locais
- Módulo de vendas/PDV
- Controle financeiro ou emissão de notas fiscais
- Compras automáticas (pedidos são manuais criados pelo gerente)
- Campo de preço em produtos

## 5. Definition of Done

Uma tarefa só está concluída quando:
- Todas as alterações funcionam no navegador via GitHub Pages + Supabase.
- Testes automatizados com Playwright em Python validam o funcionamento.
- Nenhuma dependência com servidores locais ou backend Java foi reintroduzida.
