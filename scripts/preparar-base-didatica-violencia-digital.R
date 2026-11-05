# Preparação técnica da base didática usada no livro.
#
# Este script seleciona os campos autorizados, retira a identificação
# processual e embaralha os registros antes de criar identificadores
# didáticos. Ele não realiza limpeza, recodificação ou padronização dos
# valores que serão examinados no capítulo.

if (!requireNamespace("readxl", quietly = TRUE)) {
  stop(
    paste0(
      "O pacote readxl é necessário para preparar a base didática. ",
      "Instale-o no R 4.6.1 antes de executar esta rotina."
    )
  )
}

arquivo_origem <- Sys.getenv("BASE_VIOLENCIA_DIGITAL")

if (arquivo_origem == "") {
  stop(
    paste0(
      "Defina a variável de ambiente BASE_VIOLENCIA_DIGITAL com o caminho ",
      "do arquivo acordaos_base.xlsx."
    )
  )
}

if (!file.exists(arquivo_origem)) {
  stop("Arquivo de origem não encontrado: ", arquivo_origem)
}

arquivo_saida <- "dados/violencia_digital_didatica_inicial.csv"

colunas_selecionadas <- c(
  "Tribunal:",
  "Ano da decisão",
  "Vítima:",
  "Agressor/a:",
  "A plataforma é parte na ação:",
  "Quais são as provas: prova_1",
  "prova_2",
  "prova_3",
  "prova_4",
  "As provas foram consideradas suficientes pelo juiz/juíza?",
  "Houve contestação sobre a forma de apresentação ou obtenção das provas?",
  "Decisão da primeira instância",
  "Valor da indenização na primeira instância (danos morais) | vítima 1"
)

base_original <- readxl::read_excel(
  path = arquivo_origem,
  sheet = "acordaos_base"
)

colunas_ausentes <- setdiff(colunas_selecionadas, names(base_original))

if (length(colunas_ausentes) > 0) {
  stop(
    "As seguintes colunas não foram encontradas: ",
    paste(colunas_ausentes, collapse = ", ")
  )
}

set.seed(20261105)

base_didatica <- base_original[
  sample.int(nrow(base_original)),
  colunas_selecionadas,
  drop = FALSE
]

base_didatica <- data.frame(
  id_caso = sprintf("caso_%03d", seq_len(nrow(base_didatica))),
  base_didatica,
  check.names = FALSE
)

stopifnot(
  nrow(base_didatica) == nrow(base_original),
  ncol(base_didatica) == length(colunas_selecionadas) + 1,
  !anyDuplicated(base_didatica$id_caso)
)

write.csv(
  base_didatica,
  file = arquivo_saida,
  row.names = FALSE,
  na = "NA",
  fileEncoding = "UTF-8"
)

cat("Casos preservados:", nrow(base_didatica), "\n")
cat("Variáveis disponibilizadas:", ncol(base_didatica), "\n")
cat("Arquivo criado:", arquivo_saida, "\n")
