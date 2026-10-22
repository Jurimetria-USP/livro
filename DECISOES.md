# Decisões — Livro de Jurimetria

Este documento registra as decisões consolidadas durante o desenvolvimento do Livro de Jurimetria.

As decisões poderão ser revistas pelos autores. Quando isso ocorrer, uma nova entrada deverá registrar a mudança e indicar qual decisão anterior foi substituída.

## 15 de outubro de 2026

### Escopo inicial

**Decisão:** o projeto atual será dedicado exclusivamente ao Livro de Jurimetria.

Cursos, oficinas e outros produtos didáticos serão tratados posteriormente como projetos independentes.

**Justificativa:** livro e cursos possuem estruturas, objetivos e formas de organização diferentes.

### Autoria

**Decisão:** o livro é de autoria de Alexandre Nicolella e José de Jesus Filho, da Pontifícia Universidade Católica de São Paulo (PUC-SP).

As decisões editoriais e intelectuais pertencem aos autores.

### Material central de referência

**Decisão:** o projeto `anicolella/esmat` será o principal ponto de partida para a construção do livro.

A pasta original de materiais de Jurimetria e outros projetos indicados pelos autores também poderão ser utilizados como referência.

As fontes originais não serão alteradas.

### Percurso conceitual

**Decisão:** o livro será organizado inicialmente em cinco grandes módulos:

1. Fundamentos;
2. Ambiente de trabalho e ferramentas;
3. Construção do banco de dados;
4. Descrição do fenômeno;
5. Explicação do fenômeno.

A Parte III reunirá, em capítulos próprios, a coleta dos documentos jurídicos, a extração das informações e a limpeza e estruturação do banco de dados.

A distribuição dos capítulos entre os módulos será definida progressivamente.

### Exemplos da Parte II

**Decisão:** os capítulos de ambiente de trabalho e ferramentas manterão exemplos relacionados ao Direito, especialmente os dados sobre homicídios de mulheres e feminicídios provenientes do material da ESMAT.

Os materiais do projeto `IntroducaoR` serão utilizados para aprimorar a estrutura didática e atualizar as ferramentas, sem substituir a identidade jurídica dos exemplos.

### Forma de desenvolvimento

**Decisão:** o trabalho será realizado passo a passo, preferencialmente tratando uma questão por vez.

As propostas serão apresentadas aos autores antes de alterações relevantes ou incorporação de materiais.

### Contribuição da inteligência artificial

**Decisão:** a inteligência artificial poderá analisar materiais e propor melhorias organizacionais, editoriais, técnicas e pedagógicas.

As propostas poderão incluir ajustes de escrita, clareza, estrutura, exemplos, detalhamento e integração entre os componentes do livro.

Nenhuma mudança de conteúdo será incorporada sem aprovação dos autores.

### Operações Git

**Decisão:** todas as operações Git e ações de publicação serão realizadas pelos autores.

A inteligência artificial poderá fornecer orientações, mas não executará essas operações.

### Estrutura técnica inicial

**Decisão:** o livro será desenvolvido com Quarto.

A saída renderizada será gerada na pasta `docs`, permitindo sua publicação pelo GitHub Pages.

### Repositório e página

**Decisão:** o código e os arquivos do livro serão mantidos no repositório público:

`https://github.com/Jurimetria-USP/livro`

A versão publicada estará disponível em:

`https://jurimetria-usp.github.io/livro/`

## 22 de outubro de 2026

### Organização da Parte I — Fundamentos

**Decisão:** a Parte I será organizada em quatro capítulos: método científico e desenho de pesquisa; da pergunta à conclusão; jurimetria como instrumento de pesquisa; e seleção dos litígios e desigualdades no sistema de justiça.

O primeiro capítulo corresponderá ao conteúdo do capítulo original até a seção sobre o método científico segundo Richard Feynman. O terceiro reunirá o conteúdo iniciado na antiga seção “Buscando um bom instrumento: Jurimetria”. O segundo será desenvolvido a partir do material textual já preparado para os slides, sem incorporação de fontes externas nesta etapa. Os capítulos sobre Priest–Klein e Marc Galanter serão reunidos estruturalmente, preservando os dois textos em blocos próprios.

**Justificativa:** a divisão explicita o percurso entre método científico, formulação da pergunta, aplicação da jurimetria e compreensão da seleção e das desigualdades do sistema de justiça.

### Representação de fluxos

**Decisão:** fluxos, processos e sequências de etapas serão representados com diagramas Mermaid. Listas, tabelas e texto corrido continuarão a ser escolhidos de acordo com a natureza do conteúdo.

**Justificativa:** os diagramas tornam relações sequenciais mais claras e mantêm os fluxos editáveis e integrados ao código-fonte do livro.

### Estilo da prosa

**Decisão:** a redação do livro adotará linguagem acadêmica, direta e precisa, sem adjetivação avaliativa. Listas serão utilizadas apenas quando contribuírem para classificações, enumerações técnicas, limitações, atividades ou verificações.

**Justificativa:** o padrão favorece a clareza argumentativa e distingue a exposição analítica da linguagem própria de apresentações.
