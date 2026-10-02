# Documentação do Projeto — Lume Joias (Versão 1.0 do projeto)

## 1. Link da Aplicação Hospedada

```text
GitHub Pages:
https://nickszxss.github.io/Lume-Joias/
```

---

## 2. Dados de Login da Aplicação

Os usuários abaixo estão cadastrados no banco de dados Supabase (com senhas criptografadas via BCrypt no backend Spring Boot) e também disponíveis no fallback estático para testes diretos no GitHub Pages:

| Nome     | E-mail                        | Senha       | Cargo       | Permissões / Filial |
| -------- | ----------------------------- | ----------- | ----------- | ------------------- |
| Anderson | `anderson.func@empresa.com`   | etec2026@DS | Funcionário | Filial Centro (ID 1) |
| Robson   | `robson.grt@empresa.com`      | etec2026@DS | Gerente     | Acesso Geral (5 Filiais) |
| Isabella | `isabella.func@empresa.com`   | etec2026@DS | Funcionário | Filial Norte (ID 2) |
| Manuella | `manuella.grt@empresa.com`    | etec2026@DS | Gerente     | Acesso Geral (5 Filiais) |

---

## 3. O que Falta Finalizar na Aplicação

```text
- Existem alguns erros pontuais que serão corrigidos futuramente.
- Nem todas as coisas/produtos e registros foram totalmente cadastrados no sistema.
```

---

## Detalhes Adicionais do Projeto

### Arquitetura
- **Backend:** Java 17 com Spring Boot 3.
- **Autenticação:** Endpoint `POST /api/auth/login` validando obrigatoriamente Nome, E-mail e Senha enviando `{ "nome": "...", "email": "...", "senha": "..." }`. Retorna HTTP 401 em caso de falha de validação do nome, e-mail ou senha.
- **Banco de Dados:** Supabase PostgreSQL (via Supabase Pooler IPv4/IPv6).
- **Frontend:** HTML5, CSS3, JavaScript (ES6+) e Chart.js. Logotipo do sistema servido a partir da pasta `img/` (`img/Lume.png` e `img/LumeEscuro.png`).
- **Hospedagem Frontend:** GitHub Pages (publicado automaticamente via GitHub Actions workflow `.github/workflows/static.yml` a partir do diretório `src/main/resources/static`).
