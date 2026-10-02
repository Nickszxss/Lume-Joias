# Documentação do Projeto — Lume Joias (Versão 1.0 do projeto)

## 1. Link da Aplicação Hospedada

```text
GitHub Pages:
https://nickszxss.github.io/Lume-Joias/
```

---

## 2. Dados de Login da Aplicação

Os usuários abaixo estão cadastrados no banco de dados Supabase (com senhas criptografadas via BCrypt no backend Spring Boot) e disponíveis para autenticação via backend (com fallback estático funcional para execução offline/GitHub Pages puro):

| Nome     | E-mail                        | Senha       | Cargo       | Permissões / Filial |
| -------- | ----------------------------- | ----------- | ----------- | ------------------- |
| Anderson | `anderson.func@empresa.com`   | etec2026@DS | Funcionário | Filial Centro (ID 1) |
| Robson   | `robson.grt@empresa.com`      | etec2026@DS | Gerente     | Acesso Geral (5 Filiais) |
| Isabella | `isabella.func@empresa.com`   | etec2026@DS | Funcionário | Filial Norte (ID 2) |
| Manuella | `manuella.grt@empresa.com`    | etec2026@DS | Gerente     | Acesso Geral (5 Filiais) |

---

## 3. Status de Implementação e Funcionalidades

### Funcionalidades Implementadas
- [x] **Autenticação Real:** Login com Nome, E-mail e Senha validados no backend Spring Boot contra o banco PostgreSQL no Supabase.
- [x] **Controle de Acesso e Permissões:** Separação estrita de perfis (Funcionário restrito à sua filial e sem criar pedidos de compra; Gerente com acesso às 5 filiais e permissão total para criar pedidos).
- [x] **Gestão de Produtos e Estoque:** Listagem, busca, filtro por status (Suficiente, Baixo, Zerado) e ajustes de movimentação (Entrada/Saída).
- [x] **Transferências entre Filiais:** Solicitação e conclusão de transferências de produtos entre filiais.
- [x] **Pedidos de Compra:** Criação de pedidos de compra exclusiva para Gerentes.
- [x] **Alertas de Estoque:** Painel e listagem dedicada de itens com estoque baixo ou zerado.
- [x] **Histórico Auditável:** Registro detalhado de movimentações (data/hora, produto, filial, tipo, quantidade anterior, quantidade nova, usuário e motivo).
- [x] **Identidade Visual e Logo:** Exibição da logo oficial `Lume.png` (modo claro) e `LumeEscuro.png` (modo escuro) na tela de login e na sidebar.

### Planejado / Não Implementado
- [ ] Módulo de Relatórios Avançados e exportação em PDF/Excel.
- [ ] Notificações em tempo real (WebSockets / Push Notifications).

---

## 4. Detalhes Adicionais do Projeto

### Arquitetura Real
```text
Frontend (HTML5 / CSS3 / JS ES6+)
  ↓ (API REST / JSON via HTTP)
Backend Spring Boot (Java 17)
  ↓ (Driver JDBC / HikariCP)
Banco de Dados Supabase (PostgreSQL)
```

- **Frontend:** HTML5, CSS3, JavaScript (ES6+) e Chart.js. Hospedado no GitHub Pages (disparado via GitHub Actions em `.github/workflows/static.yml` publicando o diretório `src/main/resources/static`).
- **Backend:** Java 17 com Spring Boot 3 executando a lógica de negócio, orquestração e autorização.
- **Autenticação:** Endpoint `POST /api/auth/login` validando Nome, E-mail e Senha enviando JSON `{ "nome": "...", "email": "...", "senha": "..." }`. Retorna HTTP 200 OK com o perfil do usuário ou HTTP 401 Unauthorized em caso de credenciais inválidas ou campos vazios.
- **Banco de Dados:** Supabase PostgreSQL (via Supabase Pooler IPv4/IPv6).
