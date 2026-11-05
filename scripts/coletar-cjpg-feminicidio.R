#!/usr/bin/env Rscript

# Coleta decisões de pronúncia em casos de feminicídio no Banco de Sentenças
# (CJPG) do TJSP.
#
# Usa apenas o acesso público ao e-SAJ, sem login nem certificado. A busca e a
# leitura usam o pacote tjsp. O PDF segue o link "Visualizar Inteiro Teor" da
# página pública de resultados, porque tjsp_baixar_sentenca_cjpg() passa pela
# consulta processual de 1º grau, que hoje redireciona para o login.
#
# Uso:
#   Rscript scripts/coletar-cjpg-feminicidio.R DIRETORIO INICIO FIM PAGINAS N
#
# Exemplo (10 decisões por página, sorteio de 40 pronúncias):
#   Rscript scripts/coletar-cjpg-feminicidio.R oficina-feminicidio \
#     01/01/2025 31/12/2025 todas 40

library(tidyverse)

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 5)

diretorio <- args[[1]]
inicio <- args[[2]]
fim <- args[[3]]
paginas <- if (args[[4]] == "todas") NULL else seq_len(as.integer(args[[4]]))
n_amostra <- as.integer(args[[5]])

# Códigos de assunto de feminicídio na tabela do TJSP.
assuntos_feminicidio <- c("3750", "50368", "50708")
semente <- 20261105

dir_html <- file.path(diretorio, "html")
dir_pdf <- file.path(diretorio, "pdf")
dir_triagem <- file.path(diretorio, "pdf_triagem")
dir.create(dir_html, recursive = TRUE, showWarnings = FALSE)
dir.create(dir_pdf, recursive = TRUE, showWarnings = FALSE)
dir.create(dir_triagem, recursive = TRUE, showWarnings = FALSE)

# Um PDF válido começa com "%PDF". Uma página de erro gravada com a extensão
# .pdf não passa nesta conferência.
eh_pdf <- function(arquivo) {
  file.exists(arquivo) &&
    identical(rawToChar(readBin(arquivo, "raw", n = 4)), "%PDF")
}

# O dispositivo costuma estar no fim da decisão. A regra procura o verbo no ato
# de decidir: "foi pronunciado" indica sentença posterior à pronúncia e "não pode
# ser pronunciado" indica outro desfecho. A classificação é uma triagem: a amostra
# precisa ser conferida à mão.
classificar_decisao <- function(julgado) {
  final <- str_to_lower(str_sub(julgado, -3000))
  case_when(
    is.na(final) ~ "sem texto",
    str_detect(final, "\\bimpronuncio\\b|\\bpara impronunciar\\b") ~ "impronúncia",
    str_detect(final, "\\bpronuncio\\b|\\bpara pronunciar\\b|\\bde se pronunciar\\b|\\bseja o mesmo pronunciado\\b") ~ "pronúncia",
    str_detect(final, "impronúncia") ~ "impronúncia",
    .default = "outra"
  )
}

# Segue o link público do inteiro teor. Devolve o erro em vez de escondê-lo.
baixar_inteiro_teor <- function(cd_doc, dir_pdf) {
  arquivo <- file.path(dir_pdf, str_c("decisao_", cd_doc, ".pdf"))
  if (eh_pdf(arquivo)) return("já baixado")

  partes <- str_split_1(cd_doc, "-")
  url_teor <- str_c(
    "https://esaj.tjsp.jus.br/cjpg/obterArquivo.do?cdProcesso=", partes[[1]],
    "&cdForo=", partes[[2]], "&nmAlias=", partes[[3]],
    "&cdDocumento=", partes[[4]]
  )

  visualizador <- httr::RETRY("GET", url_teor, times = 3, quiet = TRUE)
  if (str_detect(visualizador$url, "sajcas/login")) return("exige login")

  parametros <- httr::content(visualizador, "text", encoding = "UTF-8") |>
    str_extract('"parametros":"([^"]+)"', group = 1) |>
    str_remove("&deTipoDocumento=.*$")
  if (is.na(parametros)) return("sem parâmetros")
  if (str_detect(parametros, "sigiloExterno=S")) return("sigiloso")

  resposta <- httr::RETRY(
    "GET",
    str_c("https://esaj.tjsp.jus.br/pastadigital/getPDF.do?", parametros),
    httr::write_disk(arquivo, overwrite = TRUE),
    times = 3,
    quiet = TRUE
  )

  if (!eh_pdf(arquivo)) {
    file.remove(arquivo)
    return(str_c("resposta inválida (HTTP ", httr::status_code(resposta), ")"))
  }
  "baixado"
}

# 1. Resultado da busca (não repete a busca se ela já estiver gravada)
if (length(list.files(dir_html)) == 0) {
  tjsp::tjsp_baixar_cjpg(
    assunto = assuntos_feminicidio,
    inicio = inicio,
    fim = fim,
    diretorio = dir_html,
    paginas = paginas
  )
}

# 2. Metadados e texto exibido na busca
decisoes <- tjsp::tjsp_ler_cjpg(diretorio = dir_html) |>
  distinct(cd_doc, .keep_all = TRUE)

# Parte das decisões é listada sem texto na página de resultados. Sem esta etapa,
# o sorteio ficaria restrito às que têm texto. O texto delas vem do PDF.
ler_pdf <- function(cd_doc, dir_pdf) {
  arquivo <- file.path(dir_pdf, str_c("decisao_", cd_doc, ".pdf"))
  if (!eh_pdf(arquivo)) return(NA_character_)
  str_c(pdftools::pdf_text(arquivo), collapse = "\n")
}

sem_texto <- decisoes |> filter(is.na(julgado)) |> pull(cd_doc)

situacao_triagem <- map_chr(sem_texto, \(cd_doc) {
  Sys.sleep(1)
  tryCatch(
    baixar_inteiro_teor(cd_doc, dir_triagem),
    error = \(erro) str_c("erro: ", conditionMessage(erro))
  )
})

decisoes <- decisoes |>
  mutate(
    origem_texto = if_else(is.na(julgado), "pdf", "busca"),
    julgado = if_else(
      is.na(julgado),
      map_chr(cd_doc, ler_pdf, dir_pdf = dir_triagem),
      julgado
    ),
    tipo_triagem = classificar_decisao(julgado)
  )

write_rds(decisoes, file.path(diretorio, "decisoes.rds"))

# 3. Sorteio entre as pronúncias, um documento por processo
set.seed(semente)
amostra <- decisoes |>
  filter(tipo_triagem == "pronúncia") |>
  distinct(processo, .keep_all = TRUE) |>
  slice_sample(n = n_amostra)

# 4. PDFs, com uma pausa entre as consultas
situacao <- map_chr(amostra$cd_doc, \(cd_doc) {
  Sys.sleep(1)
  tryCatch(
    baixar_inteiro_teor(cd_doc, dir_pdf),
    error = \(erro) str_c("erro: ", conditionMessage(erro))
  )
})

amostra <- amostra |>
  mutate(
    arquivo = str_c("decisao_", cd_doc, ".pdf"),
    situacao_pdf = situacao
  )

write_csv(select(amostra, -julgado), file.path(diretorio, "amostra.csv"))

# Resumo da coleta
print(count(decisoes, origem_texto, tipo_triagem))
print(count(tibble(situacao_triagem), situacao_triagem))
print(count(amostra, situacao_pdf))
