lib_user <- Sys.getenv("R_LIBS_USER")
if (nzchar(lib_user) && dir.exists(lib_user)) {
  .libPaths(unique(c(lib_user, .libPaths())))
}

paquetes_requeridos <- c(
  "rmarkdown", "rticles", "knitr", "tidyverse", "mapSpain", "sf",
  "corrplot", "scales", "ggrepel", "pheatmap", "kableExtra",
  "RColorBrewer", "cluster"
)

paquetes_faltantes <- paquetes_requeridos[
  !vapply(paquetes_requeridos, requireNamespace, logical(1), quietly = TRUE)
]

if (length(paquetes_faltantes) > 0) {
  message("Instalando: ", paste(paquetes_faltantes, collapse = ", "))
  install.packages(paquetes_faltantes, repos = "https://cloud.r-project.org")
}

paquetes_sin_instalar <- paquetes_requeridos[
  !vapply(paquetes_requeridos, requireNamespace, logical(1), quietly = TRUE)
]

if (length(paquetes_sin_instalar) > 0) {
  stop(
    "No se pudieron instalar los paquetes: ",
    paste(paquetes_sin_instalar, collapse = ", ")
  )
}

message("Todos los paquetes necesarios están instalados.")
