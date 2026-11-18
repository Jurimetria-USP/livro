# Geração de uma base inteiramente sintética para fins didáticos.
#
# Nenhuma linha ou valor individual é copiado do banco usado como referência.
# O script cria casos novos, relações estatísticas planejadas e problemas de
# qualidade inseridos deliberadamente para o capítulo de limpeza de dados.

set.seed(20261117)

n_casos <- 700L
arquivo_saida <- "dados/violencia_digital_sintetica_inicial.csv"

sortear <- function(valores, tamanho, probabilidades) {
  sample(valores, size = tamanho, replace = TRUE, prob = probabilidades)
}

formatar_reais <- function(valor) {
  paste0(
    "R$ ",
    format(
      round(valor, 2),
      big.mark = ".",
      decimal.mark = ",",
      nsmall = 2,
      scientific = FALSE,
      trim = TRUE
    )
  )
}

# ---------------------------------------------------------------------------
# 1. Estrutura latente coerente
# ---------------------------------------------------------------------------

id_caso <- sprintf("CASO_S%04d", seq_len(n_casos))

tribunal_limpo <- sortear(
  c("Tribunal A", "Tribunal B", "Tribunal C", "Tribunal D", "Tribunal E", "Tribunal F"),
  n_casos,
  c(0.62, 0.22, 0.08, 0.035, 0.03, 0.015)
)

anos <- 2010:2025
pesos_ano <- c(4, 5, 6, 14, 18, 18, 18, 22, 38, 41, 45, 57, 61, 82, 84, 67)
ano_limpo <- sample(anos, n_casos, replace = TRUE, prob = pesos_ano)

vitima_limpa <- sortear(
  c("Mulher", "Homem", "Homem e mulher", "Não informado"),
  n_casos,
  c(0.88, 0.065, 0.045, 0.01)
)

agressor_limpo <- sortear(
  c("Mulher", "Homem", "Homem e mulher", "Organização", "Não informado"),
  n_casos,
  c(0.47, 0.35, 0.06, 0.02, 0.10)
)

prob_plataforma <- plogis(
  qlogis(0.125) +
    0.70 * (agressor_limpo == "Organização") +
    0.25 * (tribunal_limpo == "Tribunal A")
)
plataforma_sim <- rbinom(n_casos, 1, prob_plataforma)

# Número de classes de prova antes da introdução de inconsistências.
numero_provas <- sample(
  0:4,
  n_casos,
  replace = TRUE,
  prob = c(0.20, 0.46, 0.245, 0.07, 0.025)
)

classes_prova <- c(
  "Documental", "Print", "Depoimento", "AudioVideo", "Digital",
  "Boletim", "Imagem", "Ata", "Outros"
)

pesos_prova <- c(0.22, 0.20, 0.15, 0.13, 0.09, 0.08, 0.07, 0.025, 0.035)

variantes_prova <- list(
  Documental = c(
    "Prova documental", "Prova documental", "Prova documental",
    "Prova Documental", "Contrato", "E-mail"
  ),
  Print = c(
    "Print", "Print", "Print", "Print", "Print", "Print",
    "Transcrição das mensagens", "Dados do twitter"
  ),
  Depoimento = c("Testemunha", "Testemunha", "Depoimento", "Prova oral"),
  AudioVideo = c("Áudio", "Vídeo", "Gravação de áudio", "Áudio e vídeo"),
  Digital = c("Link URL", "Endereço de IP", "IMEI"),
  Boletim = c("Boletim de Ocorrência", "Boletim de ocorrência"),
  Imagem = c("Imagem", "Gif"),
  Ata = "Ata notarial",
  Outros = c("Prova pericial", "Processo criminal", "Laudo médico")
)

provas_brutas <- matrix(NA_character_, nrow = n_casos, ncol = 4)
colnames(provas_brutas) <- c(
  "Quais são as provas: prova_1", "prova_2", "prova_3", "prova_4"
)

for (i in seq_len(n_casos)) {
  if (numero_provas[i] == 0) {
    provas_brutas[i, 1] <- "Não cita"
  } else {
    classes_i <- sample(
      classes_prova,
      size = numero_provas[i],
      replace = FALSE,
      prob = pesos_prova
    )

    for (j in seq_along(classes_i)) {
      provas_brutas[i, j] <- sample(variantes_prova[[classes_i[j]]], 1)
    }

    # Duplicação deliberada de uma classe no mesmo caso.
    if (numero_provas[i] >= 2 && runif(1) < 0.035) {
      provas_brutas[i, numero_provas[i]] <- provas_brutas[i, 1]
    }

    # Incompatibilidade deliberada: "Não cita" junto com prova identificada.
    if (numero_provas[i] < 4 && runif(1) < 0.04) {
      provas_brutas[i, numero_provas[i] + 1] <- "Não cita"
    }
  }
}

contestacao_sim <- rbinom(
  n_casos,
  1,
  plogis(qlogis(0.09) + 0.35 * plataforma_sim)
)

prob_suficiencia <- plogis(
  1.35 +
    0.32 * pmin(numero_provas, 3) -
    1.35 * contestacao_sim
)
suficiencia_sim <- rbinom(n_casos, 1, prob_suficiencia)

sortear_resultado <- function(suficiente) {
  if (suficiente == 1) {
    sample(
      c("Procedente", "Parcialmente procedente", "Improcedente", "Não consta"),
      1,
      prob = c(0.48, 0.28, 0.237, 0.003)
    )
  } else {
    sample(
      c("Procedente", "Parcialmente procedente", "Improcedente", "Não consta"),
      1,
      prob = c(0.20, 0.20, 0.595, 0.005)
    )
  }
}

resultado_limpo <- vapply(suficiencia_sim, sortear_resultado, character(1))

# Existência e valor da indenização.
prob_valor_positivo <- plogis(
  -0.20 +
    1.00 * (resultado_limpo == "Procedente") +
    0.55 * (resultado_limpo == "Parcialmente procedente") -
    0.50 * (resultado_limpo == "Improcedente")
)

valor_ausente <- rbinom(n_casos, 1, 0.045)
valor_positivo <- ifelse(valor_ausente == 1, 0, rbinom(n_casos, 1, prob_valor_positivo))

efeito_tribunal <- c(
  "Tribunal A" = 0.55,
  "Tribunal B" = 0.45,
  "Tribunal C" = 0.00,
  "Tribunal D" = 0.00,
  "Tribunal E" = 0.00,
  "Tribunal F" = 0.00
)

media_log_valor <-
  log(6200) +
  0.55 * (agressor_limpo == "Homem") +
  0.70 * plataforma_sim +
  efeito_tribunal[tribunal_limpo]

valor_numerico <- rep(0, n_casos)
indices_positivos <- which(valor_positivo == 1)
valor_numerico[indices_positivos] <- exp(
  rnorm(length(indices_positivos), media_log_valor[indices_positivos], 0.78)
)

# Uma pequena parcela dos valores positivos recebe um choque multiplicativo.
# Esses casos formam a cauda superior usada nos exercícios sobre outliers.
n_outliers <- max(1L, round(0.025 * length(indices_positivos)))
indices_outliers <- sample(indices_positivos, n_outliers)
valor_numerico[indices_outliers] <-
  valor_numerico[indices_outliers] * runif(n_outliers, 6, 12)

valor_numerico <- pmin(round(valor_numerico, 2), 300000)

# ---------------------------------------------------------------------------
# 2. Introdução deliberada de problemas de qualidade
# ---------------------------------------------------------------------------

ano_bruto <- as.character(ano_limpo)
indices_ano <- sample(seq_len(n_casos), 12)
ano_bruto[indices_ano[1:5]] <- "Não cita"
ano_bruto[indices_ano[6:8]] <- "Não informa"
ano_bruto[indices_ano[9:11]] <- "Não identificada"
ano_bruto[indices_ano[12]] <- "2O23"

vitima_bruta <- vapply(vitima_limpa, function(valor) {
  switch(
    valor,
    Mulher = sample(c("Mulher", "Mulheres"), 1, prob = c(0.94, 0.06)),
    Homem = sample(c("Homem", "Homens"), 1, prob = c(0.91, 0.09)),
    `Homem e mulher` = sample(c("Homem e mulher", "Homens e mulheres"), 1, prob = c(0.86, 0.14)),
    `Não informado` = sample(c("Não cita", NA_character_), 1)
  )
}, character(1))

agressor_bruto <- vapply(agressor_limpo, function(valor) {
  switch(
    valor,
    Mulher = sample(c("Mulher,", "Mulher", "Mulheres"), 1, prob = c(0.82, 0.10, 0.08)),
    Homem = sample(c("Homem", "Homens", "Homem (backlash)"), 1, prob = c(0.86, 0.11, 0.03)),
    `Homem e mulher` = "Homem e mulher",
    Organização = sample(c("Empresa", "Igreja", "Partido Político", "Hotel"), 1),
    `Não informado` = sample(c("Não cita", NA_character_), 1)
  )
}, character(1))

plataforma_bruta <- ifelse(plataforma_sim == 1, "Sim", "Não")
suficiencia_bruta <- ifelse(suficiencia_sim == 1, "Sim", "Não")
contestacao_bruta <- ifelse(contestacao_sim == 1, "Sim", "Não")

resultado_bruto <- resultado_limpo
indices_improcedente <- which(resultado_bruto == "Improcedente")
if (length(indices_improcedente) >= 3) {
  resultado_bruto[sample(indices_improcedente, 3)] <- "improcedente"
}

valor_bruto <- rep(NA_character_, n_casos)

for (i in seq_len(n_casos)) {
  if (valor_ausente[i] == 1) {
    valor_bruto[i] <- sample(c("Não consta", NA_character_), 1, prob = c(0.75, 0.25))
  } else if (valor_positivo[i] == 0) {
    valor_bruto[i] <- sample(c("0", "R$ 0,00", "0,00"), 1, prob = c(0.55, 0.30, 0.15))
  } else if (runif(1) < 0.015) {
    valor_bruto[i] <- paste(sample(c(2, 3, 5, 8, 10, 15, 20), 1), "salários mínimos")
  } else {
    formato <- sample(1:4, 1, prob = c(0.55, 0.20, 0.15, 0.10))
    valor <- valor_numerico[i]

    valor_bruto[i] <- switch(
      as.character(formato),
      `1` = formatar_reais(valor),
      `2` = format(round(valor), scientific = FALSE, trim = TRUE),
      `3` = format(round(valor, 2), big.mark = ".", decimal.mark = ",", nsmall = 2, scientific = FALSE, trim = TRUE),
      `4` = paste0(
        "R$",
        format(
          round(valor),
          big.mark = ".",
          decimal.mark = ",",
          scientific = FALSE,
          trim = TRUE
        )
      )
    )
  }
}

base_sintetica <- data.frame(
  id_caso = id_caso,
  `Tribunal:` = tribunal_limpo,
  `Ano da decisão` = ano_bruto,
  `Vítima:` = vitima_bruta,
  `Agressor/a:` = agressor_bruto,
  `A plataforma é parte na ação:` = plataforma_bruta,
  `Quais são as provas: prova_1` = provas_brutas[, 1],
  prova_2 = provas_brutas[, 2],
  prova_3 = provas_brutas[, 3],
  prova_4 = provas_brutas[, 4],
  `As provas foram consideradas suficientes pelo juiz/juíza?` = suficiencia_bruta,
  `Houve contestação sobre a forma de apresentação ou obtenção das provas?` = contestacao_bruta,
  `Decisão da primeira instância` = resultado_bruto,
  `Valor da indenização na primeira instância (danos morais) | vítima 1` = valor_bruto,
  check.names = FALSE
)

# ---------------------------------------------------------------------------
# 3. Validações da base inicial
# ---------------------------------------------------------------------------

stopifnot(
  nrow(base_sintetica) == n_casos,
  ncol(base_sintetica) == 14,
  !anyDuplicated(base_sintetica$id_caso),
  any(base_sintetica[["Ano da decisão"]] == "2O23", na.rm = TRUE),
  any(base_sintetica[["Vítima:"]] == "Mulheres", na.rm = TRUE),
  any(base_sintetica[["Agressor/a:"]] == "Mulher,", na.rm = TRUE),
  any(grepl("salários mínimos", base_sintetica[[14]], fixed = TRUE), na.rm = TRUE),
  any(base_sintetica[[14]] %in% c("0", "R$ 0,00", "0,00"), na.rm = TRUE),
  any(is.na(base_sintetica[[14]]) | base_sintetica[[14]] == "Não consta")
)

tem_nao_cita <- apply(provas_brutas, 1, function(x) any(x == "Não cita", na.rm = TRUE))
tem_outra_prova <- apply(
  provas_brutas,
  1,
  function(x) any(!is.na(x) & x != "Não cita")
)

stopifnot(
  any(tem_nao_cita & tem_outra_prova),
  any(tem_nao_cita & !tem_outra_prova)
)

write.csv(
  base_sintetica,
  file = arquivo_saida,
  row.names = FALSE,
  na = "NA",
  fileEncoding = "UTF-8"
)

cat("Base sintética inicial criada.\n")
cat("Casos:", nrow(base_sintetica), "\n")
cat("Variáveis:", ncol(base_sintetica), "\n")
cat("Casos com incompatibilidade em 'Não cita':", sum(tem_nao_cita & tem_outra_prova), "\n")
cat("Casos efetivamente sem prova citada:", sum(tem_nao_cita & !tem_outra_prova), "\n")
cat("Arquivo:", arquivo_saida, "\n")
