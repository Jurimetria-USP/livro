# Tratamento reproduzível da base sintética de violência digital.
# Usa somente funções do R básico para não depender de pacotes externos.

arquivo_entrada <- "dados/violencia_digital_sintetica_inicial.csv"
arquivo_saida <- "dados/violencia_digital_sintetica_tratada.csv"

base_inicial <- read.csv(
  arquivo_entrada, check.names = FALSE, na.strings = c("", "NA"),
  encoding = "UTF-8"
)
base_limpa <- base_inicial

# Ano
ano_texto <- gsub("O", "0", base_limpa[["Ano da decisão"]], fixed = TRUE)
base_limpa$ano_decisao <- suppressWarnings(as.integer(ano_texto))

# Perfis da vítima e do agressor
vitima <- trimws(base_limpa[["Vítima:"]])
vitima_chave <- tolower(vitima)
base_limpa$perfil_vitima <- ifelse(
  is.na(vitima_chave) | vitima_chave == "não cita", "Não informado",
  ifelse(vitima_chave %in% c("mulher", "mulheres"), "Mulher",
    ifelse(vitima_chave %in% c("homem", "homens", "homem (backlash)"), "Homem",
      ifelse(vitima_chave %in% c("homem e mulher", "homens e mulheres"),
        "Homem e mulher", "Revisar"))))

agressor <- trimws(base_limpa[["Agressor/a:"]])
agressor_chave <- tolower(agressor)
organizacoes <- c(
  "empresa", "empresa de transporte", "grupo cidade de comunicação",
  "hotel", "igreja", "partido político"
)
base_limpa$perfil_agressor <- ifelse(
  is.na(agressor_chave) | agressor_chave == "não cita", "Não informado",
  ifelse(agressor_chave %in% c("mulher", "mulher,", "mulheres"), "Mulher",
    ifelse(agressor_chave %in% c("homem", "homens", "homem (backlash)"), "Homem",
      ifelse(agressor_chave == "homem e mulher", "Homem e mulher",
        ifelse(agressor_chave %in% organizacoes, "Organização", "Revisar")))))

base_limpa$plataforma_parte <- base_limpa[["A plataforma é parte na ação:"]]
base_limpa$suficiencia_probatoria <-
  base_limpa[["As provas foram consideradas suficientes pelo juiz/juíza?"]]
base_limpa$contestacao_prova <-
  base_limpa[["Houve contestação sobre a forma de apresentação ou obtenção das provas?"]]

# Resultado da primeira instância
resultado <- base_limpa[["Decisão da primeira instância"]]
base_limpa$resultado_primeira_instancia <- ifelse(
  is.na(resultado) | resultado == "Não consta", "Não consta",
  ifelse(resultado == "Procedente", "Procedente",
    ifelse(resultado == "Parcialmente procedente", "Parcialmente procedente",
      ifelse(resultado %in% c("Improcedente", "improcedente"),
        "Improcedente", "Revisar"))))
base_limpa$procedente_bin <- ifelse(
  base_limpa$resultado_primeira_instancia == "Procedente", 1L,
  ifelse(base_limpa$resultado_primeira_instancia %in%
    c("Parcialmente procedente", "Improcedente"), 0L, NA_integer_))

# Provas de múltipla resposta
colunas_prova <- c(
  "Quais são as provas: prova_1", "prova_2", "prova_3", "prova_4"
)
classificar_prova <- function(x) {
  if (is.na(x) || trimws(x) == "") return(NA_character_)
  if (x %in% c(
    "Prova documental", "Prova Documental", "Contrato", "E-mail",
    "Transcrição do storie", "Transcrição de e-mail",
    "Transcrição de dialogo", "Transcrição das postagens",
    "Transcrição das mensagens", "Processo criminal"
  )) return("Prova documental")
  if (x == "Print") return("Print")
  if (x %in% c("Testemunha", "Depoimento", "Relato de informante",
    "Prova oral", "Prova Oral")) return("Depoimento e prova testemunhal")
  if (x %in% c(
    "Áudio e vídeo", "Áudio", "Vídeo", "Gravações da reportagem",
    "Gravação de áudios", "Gravação de áudio", "Gravação de vídeo",
    "Gravação Telefonica clandestina"
  )) return("Áudio e vídeo")
  if (x %in% c("IMEI", "Endereço de IP", "Link URL")) return("IMEI/IP/URL")
  if (x %in% c("Boletim de ocorrência", "Boletim de Ocorrência"))
    return("Boletim de ocorrência")
  if (x %in% c("Imagem", "Gif")) return("Imagem")
  if (x == "Ata notarial") return("Ata notarial")
  if (x == "Não cita") return("Não cita")
  "Outros"
}

provas_matriz <- as.matrix(base_limpa[colunas_prova])
categorias_matriz <- matrix(
  vapply(as.vector(provas_matriz), classificar_prova, character(1)),
  nrow = nrow(provas_matriz), ncol = ncol(provas_matriz)
)
tem_categoria <- function(categoria) apply(
  categorias_matriz, 1,
  function(x) as.integer(any(x == categoria, na.rm = TRUE))
)
base_limpa$prova_documental <- tem_categoria("Prova documental")
base_limpa$prova_print <- tem_categoria("Print")
base_limpa$prova_depoimento_testemunhal <- tem_categoria("Depoimento e prova testemunhal")
base_limpa$prova_audio_video <- tem_categoria("Áudio e vídeo")
base_limpa$prova_imei_ip_url <- tem_categoria("IMEI/IP/URL")
base_limpa$prova_boletim_ocorrencia <- tem_categoria("Boletim de ocorrência")
base_limpa$prova_imagem <- tem_categoria("Imagem")
base_limpa$prova_ata_notarial <- tem_categoria("Ata notarial")
base_limpa$prova_outros <- tem_categoria("Outros")
base_limpa$prova_nao_cita <- apply(categorias_matriz, 1, function(x) {
  as.integer(any(x == "Não cita", na.rm = TRUE) &
    !any(!is.na(x) & x != "Não cita"))
})

# Valores monetários
salarios_minimos <- setNames(
  c(510, 545, 622, 678, 724, 788, 880, 937,
    954, 998, 1045, 1100, 1212, 1320, 1412, 1518),
  2010:2025
)
converter_numero_br <- function(x) {
  if (is.na(x)) return(NA_real_)
  texto <- gsub("R$", "", x, fixed = TRUE)
  texto <- gsub(" ", "", texto, fixed = TRUE)
  if (grepl(",", texto, fixed = TRUE)) {
    texto <- gsub(".", "", texto, fixed = TRUE)
    texto <- sub(",", ".", texto, fixed = TRUE)
  } else if (grepl("^[0-9]{1,3}(\\.[0-9]{3})+$", texto)) {
    # Ponto sem vírgula representa separador de milhares: R$12.345.
    texto <- gsub(".", "", texto, fixed = TRUE)
  }
  suppressWarnings(as.numeric(texto))
}
valor_original <- base_limpa[[
  "Valor da indenização na primeira instância (danos morais) | vítima 1"
]]
eh_salario <- grepl("salários mínimos", valor_original, fixed = TRUE)
eh_salario[is.na(eh_salario)] <- FALSE
valor_extraido <- vapply(valor_original, converter_numero_br, numeric(1))
quantidade_salarios <- suppressWarnings(as.numeric(sub(" .*", "", valor_original)))
base_limpa$forma_registro_valor <- ifelse(
  is.na(valor_original) | valor_original == "Não consta", "Não informado",
  ifelse(eh_salario, "Convertido de salários mínimos",
    ifelse(!is.na(valor_extraido), "Valor informado em reais", "Revisar")))
salario_do_ano <- unname(salarios_minimos[as.character(base_limpa$ano_decisao)])
base_limpa$valor_indenizacao_nominal <- ifelse(
  base_limpa$forma_registro_valor == "Valor informado em reais", valor_extraido,
  ifelse(base_limpa$forma_registro_valor == "Convertido de salários mínimos",
    quantidade_salarios * salario_do_ano, NA_real_))

# Atualização aproximada pelo IPCA de julho para julho de 2026
indices_ipca <- setNames(
  c(3111.05, 3324.86, 3497.70, 3717.03, 3958.72, 4337.11,
    4715.99, 4843.87, 5061.11, 5224.18, 5344.63, 5825.37,
    6411.95, 6667.94, 6967.89, 7331.98, 7657.73),
  2010:2026
)
indice_do_ano <- unname(indices_ipca[as.character(base_limpa$ano_decisao)])
base_limpa$valor_indenizacao_jul2026 <- round(
  base_limpa$valor_indenizacao_nominal * 7657.73 / indice_do_ano, 2
)

indicadores_prova <- c(
  "prova_documental", "prova_print", "prova_depoimento_testemunhal",
  "prova_audio_video", "prova_imei_ip_url", "prova_boletim_ocorrencia",
  "prova_imagem", "prova_ata_notarial", "prova_outros", "prova_nao_cita"
)
base_final <- data.frame(
  id_caso = base_limpa$id_caso,
  tribunal = base_limpa[["Tribunal:"]],
  ano_decisao = base_limpa$ano_decisao,
  perfil_vitima = base_limpa$perfil_vitima,
  perfil_agressor = base_limpa$perfil_agressor,
  plataforma_parte = base_limpa$plataforma_parte,
  base_limpa[indicadores_prova],
  suficiencia_probatoria = base_limpa$suficiencia_probatoria,
  contestacao_prova = base_limpa$contestacao_prova,
  resultado_primeira_instancia = base_limpa$resultado_primeira_instancia,
  procedente_bin = base_limpa$procedente_bin,
  forma_registro_valor = base_limpa$forma_registro_valor,
  valor_indenizacao_nominal = base_limpa$valor_indenizacao_nominal,
  valor_indenizacao_jul2026 = base_limpa$valor_indenizacao_jul2026,
  check.names = FALSE
)

# Verificações de integridade
variaveis_binarias <- c(indicadores_prova, "procedente_bin")
variaveis_categoricas <- c(
  "tribunal", "perfil_vitima", "perfil_agressor", "plataforma_parte",
  "suficiencia_probatoria", "contestacao_prova",
  "resultado_primeira_instancia", "forma_registro_valor"
)
categorias_pendentes <- sum(vapply(
  base_final[variaveis_categoricas],
  function(x) sum(x == "Revisar", na.rm = TRUE), integer(1)
))
valores_negativos <-
  sum(base_final$valor_indenizacao_nominal < 0, na.rm = TRUE) +
  sum(base_final$valor_indenizacao_jul2026 < 0, na.rm = TRUE)
stopifnot(
  nrow(base_final) == 700,
  ncol(base_final) == 23,
  length(unique(base_final$id_caso)) == 700,
  anyDuplicated(base_final$id_caso) == 0,
  categorias_pendentes == 0,
  valores_negativos == 0,
  all(vapply(base_final[variaveis_binarias],
    function(x) all(is.na(x) | x %in% c(0, 1)), logical(1)))
)

write.csv(base_final, arquivo_saida, row.names = FALSE, na = "")
cat("Base tratada gravada em:", arquivo_saida, "\n")
cat("Linhas:", nrow(base_final), "| Colunas:", ncol(base_final), "\n")
cat("Categorias pendentes:", categorias_pendentes, "\n")
