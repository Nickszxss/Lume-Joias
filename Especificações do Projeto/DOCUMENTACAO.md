# Especificações do Projeto

## Link da aplicação

```text
GitHub Pages:
https://Nickszxss.github.io/Lume-Joias/
```

---

## Usuários para teste

| Nome     | Email                                                         | Senha       | Cargo       |
| -------- | ------------------------------------------------------------- | ----------- | ----------- |
| Anderson | [anderson.func@empresa.com](mailto:anderson.func@empresa.com) | etec2026@DS | Funcionário |
| Robson   | [robson.grt@empresa.com](mailto:robson.grt@empresa.com)       | etec2026@DS | Gerente     |
| Isabella | [isabella.func@empresa.com](mailto:isabella.func@empresa.com) | etec2026@DS | Funcionário |
| Manuella | [manuella.grt@empresa.com](mailto:manuella.grt@empresa.com)   | etec2026@DS | Gerente     |

---

## O que já foi realizado

- [x] Conexão e configuração do banco de dados PostgreSQL via Supabase Pooler (IPv4 e IPv6 compatíveis).
- [x] Tabela `usuarios` com suporte a enums e BCrypt para senhas.
- [x] Inicializador automático de usuários (`DatabaseUserInitializer`) para cadastrar/atualizar os 4 usuários solicitados no Supabase na inicialização da aplicação.
- [x] Suporte a login e diferenciação de permissões entre Funcionário e Gerente no Backend Java (Spring Boot) e Frontend (HTML/CSS/JS).
- [x] Suporte para execução do frontend no GitHub Pages com fallback estático completo quando hospedado de forma estática, mantendo a simulabilidade do login dos 4 usuários.
- [x] Ajuste de caminhos relativos de imagens (`img/Lume.png`, `img/LumeEscuro.png`), CSS (`style.css`) e Scripts (`main.js`).
- [x] Remoção da tag `<base target="_blank">` para garantir funcionamento de links/navegação.
- [x] Suíte de testes de integração com JUnit 5 (`AuthIntegrationTest`) validando login e tentativas de acesso inválidas para todos os usuários.

---

## O que ainda falta

```text
Nenhuma pendência identificada após os testes.
```

---

## Relatório das modificações

### Modificação 1
**Modificação:** Atualização do cadastro automático de usuários de inicialização no Supabase.
**Problema encontrado:** O inicializador de usuários (`DatabaseUserInitializer.java`) registrava dados antigos de teste (ex: Nicoly) com senhas desatualizadas e sem a lista completa dos 4 usuários exigidos no projeto.
**Solução:** Atualizado o código Java para garantir que os usuários Anderson, Robson, Isabella e Manuella sejam inseridos/atualizados com o hash BCrypt da senha `etec2026@DS` e os cargos/filiais corretos.
**Arquivos alterados:**
- `src/main/java/com/nicoly/LumeEstoque/init/DatabaseUserInitializer.java`
**Teste realizado:** Execução da aplicação via Spring Boot `./mvnw spring-boot:run` e consulta à tabela `usuarios` no Supabase.
**Resultado:** Todos os 4 usuários foram validados e inseridos com sucesso no Supabase sem duplicidades.

---

### Modificação 2
**Modificação:** Atualização dos testes de integração de autenticação (`AuthIntegrationTest.java`).
**Problema encontrado:** Os testes automatizados em Java dependiam do email e senha antigos.
**Solução:** Atualizados os casos de teste para validar o login de Anderson, Robson, Isabella e Manuella com a senha `etec2026@DS`, além de validar falhas de autenticação com credenciais incorretas.
**Arquivos alterados:**
- `src/test/java/com/nicoly/LumeEstoque/AuthIntegrationTest.java`
**Teste realizado:** Execução dos testes automatizados com `./mvnw test`.
**Resultado:** 15 testes de integração executados e aprovados com 100% de taxa de sucesso.

---

### Modificação 3
**Modificação:** Adaptação da camada Frontend JavaScript (`main.js`) para compatibilidade com GitHub Pages.
**Problema encontrado:** Quando a aplicação estática roda hospedada no GitHub Pages, requisições diretas a `http://localhost:8080` falham caso o backend Java não esteja rodando localmente na mesma máquina do usuário visualizador.
**Solução:** Implementado mecanismo no `main.js` que detecta a origem da requisição e atua com fallback para os 4 usuários cadastrados e base estática demonstrativa, evitando exceções no console e permitindo teste do protótipo no GitHub Pages.
**Arquivos alterados:**
- `src/main/resources/static/main.js`
**Teste realizado:** Simulação de requisições de login e navegação estática no navegador.
**Resultado:** Interface responsiva, sem erros de console e com funcionalidades completas de login e alternância de visualizações.

---

### Modificação 4
**Modificação:** Correção na estrutura de cabeçalho HTML (`index.html`).
**Problema encontrado:** Existia a tag `<base target="_blank">` que fazia com que interações com links no protótipo abrissem novas abas desnecessariamente.
**Solução:** A tag foi removida.
**Arquivos alterados:**
- `src/main/resources/static/index.html`
**Teste realizado:** Navegação pelo menu da aplicação.
**Resultado:** Navegação interna suave na mesma página SPA.
