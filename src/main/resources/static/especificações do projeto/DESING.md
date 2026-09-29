# Design System e Especificações de Interface (Lume Joias)

Com base nas capturas de tela fornecidas do protótipo, elaborei as especificações visuais (Design System) para a implementação do Front-end.

## 1. Paleta de Cores

A interface adota um estilo elegante e minimalista (Clean Design), focado no contraste entre tons neutros e uma cor de destaque forte que remete à identidade visual da joalheria.

* **Cor Primária (Destaque, Botões, Menu Ativo):** Vinho / Bordô (Aprox. `#8A3B58`) — Usada no logotipo principal, no botão "Entrar" e no item ativo "Dashboard" do menu lateral.


* **Fundo da Aplicação (Background):** Cinza Super Claro (Aprox. `#F9FAFB`) — Proporciona um contraste suave com os painéis em branco, ajudando a destacar a área de trabalho.


* **Superfícies (Cards, Sidebar, Container de Login):** Branco Puro (`#FFFFFF`) — Utilizado como fundo de destaque para estruturar o formulário de login e os painéis gráficos.


* **Texto Principal (Títulos, Textos Padrão):** Chumbo / Cinza Muito Escuro (Aprox. `#1F2937`) — Garante alta legibilidade no título "Dashboard" e nos textos digitados nos inputs.


* **Texto Secundário e Labels:** Cinza Médio (Aprox. `#6B7280`) — Usado nos subtítulos ("Visão geral das 5 filiais"), placeholders e rótulos ("NOME DO USUÁRIO").


* **Bordas e Divisórias:** Cinza Claro (Aprox. `#E5E7EB`) — Define o contorno dos inputs, dos cards e as linhas divisórias laterais de forma sutil.



## 2. Tipografia

A tipografia mescla a tradição de uma marca de joias com a clareza funcional exigida por um sistema de gestão.

* **Logotipo e Título Principal (Login):** Fonte Serifada (ex: *Playfair Display* ou *Merriweather*), utilizada especificamente no texto "Lume Joias" para transmitir sofisticação.


* **Interface Geral (Menus, Formulários, Dashboards):** Fonte Sans-Serif limpa e geométrica. Uma excelente opção para o desenvolvimento deste front-end é a família **Century Gothic**, que mantém a elegância arredondada da marca enquanto garante perfeita leitura em telas complexas.
* **Pesos Tipográficos Utilizados:**
* *Regular (400):* Textos de corpo, subtítulos e itens de menu inativos.


* *Medium/Semibold (500/600):* Rótulos de formulário, abas de filtro e títulos internos de painéis.


* *Bold (700):* Títulos principais de página (ex: "Dashboard").





## 3. Estrutura de Layout (Dashboard)

O sistema adota um layout responsivo de painel administrativo (Dashboard) em ocupação de tela cheia.

* **Sidebar (Barra Lateral Esquerda):**
* Fundo branco, separada da área principal por uma borda fina vertical.


* **Topo:** Logotipo "Lume" centralizado.


* **Navegação:** Lista de itens com ícones vazados (outline) à esquerda do texto. O item ativo da página (ex: "Dashboard") é preenchido com a Cor Primária, com o texto e o ícone alterados para branco.


* **Rodapé:** Agrupa as configurações de interface (botão "Modo Escuro") e o perfil do usuário logado contendo o cargo, o nome e um botão de logout.




* **Área de Conteúdo (Main Content):**
* Margens internas amplas (padding) para criar "respiro" na interface.


* **Cabeçalho:** Contém o Título da página alinhado à esquerda e, na mesma linha alinhado à direita, o seletor de filtros das filiais.





## 4. Componentes de UI

* **Botões de Ação Principais:**
* Preenchimento sólido na Cor Primária.


* Texto em branco, centralizado.


* Cantos levemente arredondados (Border-radius de aprox. `4px` a `6px`).




* **Campos de Formulário (Inputs):**
* Fundo branco com contorno fino em Cinza Claro.


* Os rótulos (Labels) estão posicionados acima dos campos, em letras maiúsculas (uppercase) e em tamanho reduzido.


* Cantos suavemente arredondados.




* **Cards de Informação (Widgets do Dashboard):**
* Painéis brancos com contorno fino (`1px solid`) em cinza claro, sem sombras pesadas (Flat design).


* Títulos inseridos no topo esquerdo com margem interna confortável.




* **Filtros em Abas (Tabs - "Todas", "Centro", etc):**
* Organizados em um contêiner horizontal único com borda dividindo as opções.


* O filtro ativo ("Todas") recebe destaque com a cor do texto na Cor Primária (Vinho/Bordô).