# Documentação do Projeto — Lume Joias (Versão 1.0 do projeto)

## 1. Link da Aplicação Hospedada

```text
GitHub Pages:
https://nickszxss.github.io/Lume-Joias/
```

---

## 2. Dados de Login da Aplicação

Os usuários abaixo estão cadastrados no banco de dados Supabase (com senhas criptografadas via BCrypt) e autenticados com segurança via RPC PostgreSQL (`validar_login` com `pgcrypto` server-side) sem dependência de backend Java:

| Nome     | E-mail                        | Senha       | Cargo       | Permissões / Filial |
| -------- | ----------------------------- | ----------- | ----------- | ------------------- |
| Anderson | `anderson.func@empresa.com`   | etec2026@DS | Funcionário | Filial Centro (ID 1) |
| Robson   | `robson.grt@empresa.com`      | etec2026@DS | Gerente     | Acesso Geral (5 Filiais) |
| Isabella | `isabella.func@empresa.com`   | etec2026@DS | Funcionário | Filial Norte (ID 2) |
| Manuella | `manuella.grt@empresa.com`    | etec2026@DS | Gerente     | Acesso Geral (5 Filiais) |

---

## 3. Módulo de Dashboard e Gráficos

* **Indicadores/KPIs:** Total de itens em estoque, produtos cadastrados, itens com estoque baixo, estoque zerado e transferências pendentes.
* **Gráfico 1 (Estoque por Filial):** Gráfico de barras (Chart.js) que calcula a soma das quantidades de produtos da tabela `estoques` para cada uma das 5 filiais (`Filial Centro`, `Filial Norte`, `Filial Sul`, `Filial Leste`, `Filial Oeste`).
* **Gráfico 2 (Movimentações na Semana):** Gráfico de linhas (Chart.js) que consulta a tabela `movimentacoes` do Supabase para os últimos 7 dias, agrupando as quantidades por dia da semana (`['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']`) divididas em séries de `entradas` e `saidas`.
* **Gerenciamento de Instâncias:** As instâncias anteriores do Chart.js (`chartFilial`, `chartMov`) são destruídas com `.destroy()` antes de cada nova renderização para evitar conflitos no canvas.

---

## 4. Matriz de Homologação de Testes e Segurança

| Módulo / Funcionalidade | Status | Método de Teste | Observações |
| :--- | :--- | :--- | :--- |
| **Autenticação** | Aprovado | Automatizado & Manual | RPC PostgreSQL `validar_login` com `pgcrypto` validada. Bypass por mock desativado em produção. |
| **Permissões de Perfil** | Aprovado | Automatizado & Manual | Escopo de 5 filiais e criação de pedidos restrita a Gerentes. Funcionários restritos à própria filial. |
| **Estoque** | Aprovado | Automatizado | Ajustes manuais de entrada/saída gravando saldo e status sem permitir saldo negativo. |
| **Transferências** | Aprovado | Automatizado | Conclusão atômica com baixa na origem, crédito no destino e gravação dupla no histórico. |
| **Pedidos de Compra** | Aprovado | Automatizado | Nomes de produtos resolvidos sem rótulo genérico e quantidade exibida corretamente. |
| **Dashboard** | Aprovado | Automatizado | KPIs, gráfico de barras por filial e gráfico de linha de movimentações dos últimos 7 dias. |
| **Histórico** | Aprovado | Automatizado | Responsáveis identificados pelo nome real da tabela `usuarios`. |
| **Responsividade** | Aprovado | Playwright (Video/Screenshot) | Testado em Desktop (1280x800), Tablet (768x1024) e Smartphone (375x667) nos temas Claro e Escuro. |
| **Segurança & RLS** | Aprovado | Auditoria de Código | Senhas isoladas no banco, chave pública anon sem permissão de escrita arbitrária em usuários. |

---

## 5. Problemas Conhecidos, Limitações e Dependências Externas

* **Dependência do Supabase:** Como a aplicação executa client-side (SPA no GitHub Pages), a disponibilidade total depende dos serviços do Supabase (REST/RPC).
* **Execução das Migrações e RPCs:** A validação segura de login via `validar_login` requer a execução prévia do script SQL com a extensão `pgcrypto` no Supabase.
* **Limitação do Chart.js em Viewports Extremamente Pequenos (<320px):** Em telas com menos de 320px de largura, a legenda do Chart.js de movimentações semanais pode sofrer quebra de linha.

---

## 6. Design System e Responsividade

* **Breakpoints CSS:** Unificado em `@media (max-width: 900px)` para transição do menu lateral (sidebar de 220px) para cabeçalho superior fixo com barra de navegação pill horizontal (`#menu`), cobrindo perfeitamente Tablets (768px x 1024px) e Smartphones (375px x 667px).
* **Rolagem e Usabilidade de Tabelas:** Todas as tabelas são contidas em cards com `overflow-x: auto` com suporte a toque (`-webkit-overflow-scrolling: touch`), scrollbars na cor rose primary e indicação visual `"← Deslize para ver mais →"`.
* **Identidade Visual:** Paleta rose primária (`#9d3b5c` para light mode e `#c65b7e` para dark mode), fontes Cormorant Garamond, Montserrat e Poppins mantidas e testadas.

---

## 5. Módulo de Histórico e Movimentações

* **Tabela Supabase:** `movimentacoes`
* **Identificação do Responsável:** Cruzamento da FK `usuario_id` com a tabela `usuarios` (`client.from('usuarios').select('id, nome')`), eliminando a exibição do nome genérico `'Usuário'`. Registros antigos ou sem usuário vinculado apresentam o rótulo amigável `'Sistema'`.
* **Auditoria de Operações:** Gravado o `usuario_id` do operador em ajustes manuais de estoque e nas 2 movimentações geradas na conclusão de transferências (saída na origem e entrada no destino).

---

## 5. Módulo de Pedidos de Compra

* **Tabela Supabase:** `pedidos_compra`
* **Mapeamento de Campos:** Suporte flexível às variações de colunas (`quantidade` / `qtd`, `produto_id` / `produtoId`, `filial_id` / `filialId`, `solicitante` / `usuario`).
* **Relacionamento com Produtos:** Cruzamento seguro de IDs (`String(prd.id) === String(p.produto_id)`) com fallback para o nome retornado pela lista de produtos em cache (`nomeProduto()`) ou identificador `Produto #ID` em registros incompletos, eliminando exibições de `undefined` e `Produto` genérico.
* **Permissões:** Criação de pedidos restrita exclusivamente a usuários com perfil `gerente`.

---

## 4. Status de Implementação e Funcionalidades

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
