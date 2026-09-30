# Especificações e Documentação do Projeto — Lume Joias

## Link da Aplicação

```text
GitHub Pages:
https://nickszxss.github.io/Lume-Joias/
```

---

## Visão Geral do Projeto

O **Lume Joias** é um Sistema de Gerenciamento de Estoque (SGE) multi-filial (5 filiais: Centro, Norte, Sul, Leste e Oeste) desenvolvido em Java 17 com **Spring Boot** no backend e um frontend estático responsivo em HTML5, CSS3 e JavaScript. O banco de dados relacional é hospedado no **Supabase (PostgreSQL)**, utilizando pooling e conexão segura via JDBC.

---

## Usuários de Teste (Cadastrados no Banco e Simuláveis)

| Nome     | E-mail                        | Senha       | Cargo       | Filial Atribuída |
| -------- | ----------------------------- | ----------- | ----------- | ---------------- |
| Anderson | `anderson.func@empresa.com`   | etec2026@DS | Funcionário | Filial Centro (1)|
| Robson   | `robson.grt@empresa.com`      | etec2026@DS | Gerente     | Todas (Geral)    |
| Isabella | `isabella.func@empresa.com`   | etec2026@DS | Funcionário | Filial Norte (2) |
| Manuella | `manuella.grt@empresa.com`    | etec2026@DS | Gerente     | Todas (Geral)    |

---

## Funcionalidades e Escopo Concluído

- [x] **Backend Spring Boot 3**:
  - Rest APIs para Autenticação (`/api/auth/login`), Filiais (`/api/filiais`), Produtos (`/api/produtos`), Estoque (`/api/estoque`), Transferências (`/api/transferencias`), Pedidos de Compra (`/api/pedidos`), Alertas (`/api/estoque/alertas`), Histórico (`/api/historico`) e Dashboard (`/api/dashboard`).
  - Criptografia de senhas com BCrypt (`PasswordEncoder`).
  - Povoamento e sincronização automática dos 4 usuários no Supabase ao iniciar a aplicação (`DatabaseUserInitializer`).
- [x] **Banco de Dados Supabase (PostgreSQL)**:
  - Compatibilidade IPv4 e IPv6 via Supabase Pooler (`aws-0-us-east-1.pooler.supabase.com`).
  - Suporte aos enums de status (`status_transferencia` e `status_pedido`).
- [x] **Frontend Responsivo**:
  - Interface moderna com suporte a Modo Escuro / Modo Claro.
  - Painel de Dashboard com métricas KPI e gráficos dinâmicos (Chart.js).
  - Controle de acesso por perfil (Gerente e Funcionário).
- [x] **Publicação no GitHub Pages**:
  - Configuração via GitHub Actions Workflow (`.github/workflows/static.yml`) publicando os recursos estáticos a partir de `src/main/resources/static`.
  - Fallback local no JavaScript (`main.js`) permitindo testes e simulações completas no GitHub Pages sem expor o backend local.
  - Imagens do projeto (`Lume.png` e `LumeEscuro.png`) mantidas de forma organizada em `src/main/resources/static/img/`.

---

## Relatório das Modificações Recentes

### Modificação 1: Ajuste e Correção da Publicação no GitHub Pages
- **Problema:** O GitHub Pages apresentava erro 404/página padrão por divergência de configuração da origem de publicação.
- **Solução:** Configurado o workflow do GitHub Actions (`.github/workflows/static.yml`) para realizar o upload e deploy do diretório `src/main/resources/static`, garantindo compatibilidade com o servidor Spring Boot e com a hospedagem estática.
- **Arquivos alterados:**
  - `.github/workflows/static.yml`
  - `src/main/resources/static/index.html`
  - `src/main/resources/static/main.js`

### Modificação 2: Organização e Manutenção dos Recursos Estáticos
- **Problema:** Existência de diretórios temporários na raiz do repositório.
- **Solução:** Mantida a estrutura oficial de arquivos estáticos em `src/main/resources/static/`, garantindo que o Spring Boot sirva as páginas e imagens (`/img/Lume.png` e `/img/LumeEscuro.png`) nativamente e o GitHub Pages as publique diretamente do mesmo diretório.
- **Arquivos alterados:**
  - `src/main/resources/static/img/Lume.png`
  - `src/main/resources/static/img/LumeEscuro.png`

---

## Status dos Testes

```text
Testes de Integração e Compilação (Maven / JUnit 5):
- Tests run: 15, Failures: 0, Errors: 0, Skipped: 0
- Status: 100% APROVADO
```
