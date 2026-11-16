# Simulação da base didática usada nos capítulos sobre o tempo do processo.
#
# Os dados são inteiramente simulados. Nenhum processo, vara, perito ou
# resultado corresponde a casos reais, e os parâmetros não reproduzem os de
# nenhuma pesquisa. A simulação imita a estrutura de uma ação de
# procedimento comum que depende de perícia: emenda ou indeferimento da
# inicial, citação, nomeação do perito, laudo, acordo ou sentença, além do
# pedido de tutela de urgência.
#
# O script grava dois arquivos em dados/:
#
# - duracao_processos_simulados.csv: um processo por linha, com as
#   características conhecidas na distribuição, o perito (quando nomeado até
#   a coleta), a data da coleta e, nas colunas iniciadas por real_, a
#   trajetória completa que só a simulação conhece;
# - duracao_movimentos_simulados.csv: um movimento por linha, somente os
#   registrados até a data da coleta de cada processo.
#
# Execute a partir da raiz do projeto:
#   Rscript scripts/simular-base-didatica-duracao.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

set.seed(20261115)

n <- 4000
inicio <- as.Date("2024-01-01")
fim <- as.Date("2025-12-31")
lotes_coleta <- as.Date(c("2026-01-12", "2026-01-19", "2026-01-26"))

# Características conhecidas na distribuição ---------------------------------

faixas <- c("até R$ 30 mil", "R$ 30 mil a R$ 100 mil", "acima de R$ 100 mil")

processos <- tibble(
  processo = sprintf("SIM-%04d", seq_len(n)),
  data_distribuicao = sort(
    inicio + sample(0:as.integer(fim - inicio), n, replace = TRUE)
  ),
  vara = sample(paste("Vara", LETTERS[1:4]), n, replace = TRUE),
  faixa_valor = sample(faixas, n, replace = TRUE, prob = c(0.45, 0.35, 0.20)),
  tutela_pedida = runif(n) < 0.35,
  inicial_instruida = runif(n) < 0.60,
  data_coleta = sample(lotes_coleta, n, replace = TRUE)
)

# Peritos: as quatro varas nomeiam peritos do mesmo cadastro, com cargas de
# trabalho desiguais. O efeito de cada perito altera a chance de o laudo
# concluir a favor do autor.

peritos <- sprintf("Perito %02d", 1:40)
carga_perito <- rgamma(40, shape = 1.2)
efeito_perito <- rnorm(40, mean = 0, sd = 0.7)

# Trajetória latente, em dias desde a distribuição ---------------------------

sorteio_inteiro <- function(de, ate) sample(de:ate, n, replace = TRUE)

instruida <- processos$inicial_instruida

# Emenda e indeferimento da inicial.
emenda <- runif(n) < ifelse(instruida, 0.15, 0.40)
t_emenda <- sorteio_inteiro(5, 30)
indeferida <- emenda & runif(n) < ifelse(instruida, 0.25, 0.45)
t_indeferimento <- t_emenda + sorteio_inteiro(20, 75)
t_citacao <- ifelse(
  emenda, t_emenda + sorteio_inteiro(10, 40), sorteio_inteiro(3, 20)
)
t_contestacao <- t_citacao + sorteio_inteiro(15, 40)

# Nomeação do perito, laudo e manifestação das partes sobre o laudo.
t_nomeacao <- t_contestacao + sorteio_inteiro(5, 40)
indice_perito <- sample.int(40, n, replace = TRUE, prob = carga_perito)
t_laudo <- t_nomeacao + round(rgamma(n, shape = 4, scale = 28))
favoravel <- runif(n) <
  plogis(0.1 + 0.6 * instruida + efeito_perito[indice_perito])
t_manifestacao <- t_laudo + sorteio_inteiro(2, 25)

# Desistência ou abandono, possíveis apenas antes do laudo.
t_desistencia <- 10 + round(rexp(n, rate = 1 / 2700))
desistencia <- !indeferida & t_desistencia < t_laudo

# Depois do laudo: acordo, que não depende da vara, ou sentença. As varas
# diferem apenas na velocidade da sentença; a chance final de cada desfecho
# é a mesma nas quatro.
acordo <- favoravel & runif(n) < 0.45
t_acordo <- t_laudo + 1 + round(rgamma(n, shape = 3, scale = 12))
procedente <- ifelse(favoravel, runif(n) < 0.88, runif(n) < 0.10)
parcial <- runif(n) < 0.30
ritmo_vara <- c("Vara A" = 1, "Vara B" = 1.25, "Vara C" = 1.5, "Vara D" = 2.4)
ritmo_valor <- setNames(c(1, 1.1, 1.25), faixas)
ritmo_tutela <- ifelse(processos$tutela_pedida, 0.85, 1)
t_sentenca <- t_manifestacao + round(rgamma(
  n,
  shape = 3,
  scale = 25 * ritmo_vara[processos$vara] *
    ritmo_valor[processos$faixa_valor] * ritmo_tutela
))
t_conclusao <- pmax(t_manifestacao + 1, t_sentenca - sorteio_inteiro(3, 30))

real_desfecho <- case_when(
  indeferida | desistencia ~ "extinto",
  acordo ~ "acordo",
  procedente ~ "procedente",
  .default = "improcedente"
)
real_tempo <- case_when(
  indeferida ~ t_indeferimento,
  desistencia ~ t_desistencia,
  acordo ~ t_acordo,
  .default = t_sentenca
)
teve_laudo <- !indeferida & !desistencia
teve_nomeacao <- !indeferida & (!desistencia | t_desistencia > t_nomeacao)

# Pedido de tutela de urgência: decisão em dias, às vezes precedida de uma
# decisão que apenas adia a apreciação. A Vara D decide mais devagar.
tutela <- processos$tutela_pedida
sorteio_tutela <- runif(n)
t_tutela <- case_when(
  sorteio_tutela < 0.18 ~ 0,
  sorteio_tutela < 0.40 ~ 1,
  .default = 2 + rgeom(n, 0.18) +
    ifelse(processos$vara == "Vara D", rgeom(n, 0.30), 0)
)
postergada <- tutela & runif(n) < 0.20
t_postergacao <- sorteio_inteiro(0, 2)
t_tutela <- ifelse(postergada, t_postergacao + sorteio_inteiro(5, 20), t_tutela)
tutela_deferida <- runif(n) < 0.40
# Se a inicial for indeferida antes da decisão, o pedido fica prejudicado.
tutela_prejudicada <- tutela & indeferida & t_indeferimento <= t_tutela

# Base de processos ----------------------------------------------------------

d0 <- processos$data_distribuicao

processos <- processos |>
  mutate(
    perito = ifelse(
      teve_nomeacao & d0 + t_nomeacao <= data_coleta,
      peritos[indice_perito],
      NA_character_
    ),
    real_desfecho = real_desfecho,
    real_data_desfecho = d0 + real_tempo,
    real_data_laudo = as.Date(ifelse(teve_laudo, d0 + t_laudo, NA)),
    real_laudo_favoravel = ifelse(teve_laudo, favoravel, NA),
    real_tutela = case_when(
      !tutela ~ NA_character_,
      tutela_prejudicada ~ "prejudicada",
      tutela_deferida ~ "deferida",
      .default = "indeferida"
    ),
    real_data_tutela = as.Date(case_when(
      !tutela ~ NA,
      tutela_prejudicada ~ d0 + t_indeferimento,
      .default = d0 + t_tutela
    ))
  ) |>
  relocate(perito, .after = inicial_instruida)

# Movimentos -----------------------------------------------------------------

movimento <- function(condicao, dia, titulo) {
  tibble(processo = processos$processo, dia = dia, movimento = titulo)[condicao, ]
}

sentenca_titulo <- case_when(
  procedente & parcial ~ "Julgado procedente em parte o pedido",
  procedente ~ "Julgado procedente o pedido",
  .default = "Julgado improcedente o pedido"
)
tutela_titulo <- ifelse(
  tutela_deferida,
  "Concedida a tutela de urgência",
  "Indeferida a tutela de urgência"
)
via_sentenca <- teve_laudo & !acordo
segue <- !indeferida

movimentos <- bind_rows(
  movimento(TRUE, 0, "Distribuído por sorteio"),
  movimento(emenda, t_emenda, "Determinada a emenda da inicial"),
  movimento(indeferida, t_indeferimento, "Indeferida a petição inicial"),
  movimento(
    segue & (!desistencia | t_desistencia > t_citacao),
    t_citacao, "Expedida a citação"
  ),
  movimento(
    segue & (!desistencia | t_desistencia > t_contestacao),
    t_contestacao, "Contestação juntada"
  ),
  movimento(teve_nomeacao, t_nomeacao, "Nomeado perito"),
  movimento(
    desistencia, t_desistencia - sorteio_inteiro(1, 10),
    "Pedido de desistência juntado"
  ),
  movimento(
    desistencia, t_desistencia,
    "Extinto o processo sem resolução do mérito"
  ),
  movimento(teve_laudo, t_laudo, "Laudo pericial juntado"),
  movimento(
    teve_laudo & (!acordo | t_manifestacao < t_acordo), t_manifestacao,
    "Determinada a manifestação sobre o laudo"
  ),
  movimento(
    teve_laudo & acordo, t_acordo - sorteio_inteiro(1, 5),
    "Proposta de acordo juntada"
  ),
  movimento(teve_laudo & acordo, t_acordo, "Homologado o acordo"),
  movimento(via_sentenca, t_conclusao, "Conclusos para sentença"),
  movimento(via_sentenca, t_sentenca, sentenca_titulo),
  movimento(
    TRUE, real_tempo + sorteio_inteiro(60, 150), "Arquivado definitivamente"
  ),
  movimento(
    postergada & !tutela_prejudicada, t_postergacao,
    "Postergada a apreciação da tutela de urgência"
  ),
  movimento(tutela & !tutela_prejudicada, t_tutela, tutela_titulo)
)

# Movimentos de expediente, sem efeito sobre a duração.
expediente <- c(
  "Petição juntada", "Ato ordinatório praticado", "Certidão expedida",
  "Documento juntado"
)
quantidade <- rpois(n, 4)
movimentos <- bind_rows(
  movimentos,
  tibble(
    processo = rep(processos$processo, quantidade),
    dia = floor(runif(sum(quantidade)) * rep(real_tempo, quantidade)),
    movimento = sample(expediente, sum(quantidade), replace = TRUE)
  )
)

# Suspensão geral dos prazos no fim do ano, lançada em todos os processos
# em andamento. Não é uma suspensão do processo.
recessos <- as.Date(c("2024-12-20", "2025-12-20"))
for (recesso in as.list(recessos)) {
  em_andamento <- d0 < recesso & d0 + real_tempo > recesso
  movimentos <- bind_rows(
    movimentos,
    movimento(em_andamento, as.integer(recesso - d0), "Suspensão do prazo")
  )
}

movimentos <- movimentos |>
  inner_join(
    select(processos, processo, data_distribuicao, data_coleta),
    by = "processo"
  ) |>
  mutate(data = data_distribuicao + dia) |>
  filter(data <= data_coleta) |>
  select(processo, data, movimento) |>
  arrange(processo, data)

# Gravação -------------------------------------------------------------------

write_csv(processos, "dados/duracao_processos_simulados.csv", na = "")
write_csv(movimentos, "dados/duracao_movimentos_simulados.csv", na = "")

message(
  "Gravados ", nrow(processos), " processos e ", nrow(movimentos),
  " movimentos em dados/."
)
