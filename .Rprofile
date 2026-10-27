# Mantém a impressão de caracteres acentuados durante a renderização no Windows.
if (identical(.Platform$OS.type, "windows")) {
  invisible(suppressWarnings(
    Sys.setlocale("LC_CTYPE", "Portuguese_Brazil.utf8")
  ))
}
