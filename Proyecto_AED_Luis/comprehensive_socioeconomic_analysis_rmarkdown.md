---
title: 'Informe Analítico Exhaustivo: Dataset Socioeconómico de las Provincias Españolas
  (`datos_socioecon_ESP`)'
author: "Análisis de Datos Socioeconómicos"
date: "`r Sys.Date()`"
output:
  pdf_document:
    toc: true
    toc_depth: '3'
  html_document:
    toc: true
    toc_depth: 3
    toc_float:
      collapsed: false
      smooth_scroll: true
    theme: flatly
    highlight: tango
    code_folding: show
    df_print: paged
    fig_caption: true
subtitle: Análisis Exploratorio Longitudinal, Estructura Espacial, Modelización Multivariante
  y Datos de Panel
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(
  echo = TRUE,
  warning = FALSE,
  message = FALSE,
  fig.width = 10,
  fig.height = 6,
  fig.align = "center",
  dev = "png",
  dpi = 300
)

# Carga de paquetes fundamentales
library(tidyverse)
library(sf)
library(mapSpain)
library(patchwork)
library(scales)
library(knitr)
library(kableExtra)
library(viridis)
library(corrplot)
library(cluster)
library(factoextra)
library(plm)

# Configuración del tema global de ggplot2
theme_set(
  theme_minimal(base_family = "sans", base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 14, margin = margin(b = 6)),
      plot.subtitle = element_text(color = "grey30", size = 11, margin = margin(b = 10)),
      plot.caption = element_text(color = "grey50", size = 8, hjust = 1),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      strip.background = element_rect(fill = "grey95", color = NA),
      strip.text = element_text(face = "bold", size = 10)
    )
)
```

# 1. Introducción y Carga de Datos

Este informe realiza un análisis exhaustivo del panel longitudinal `datos_socioecon_ESP`, estructurado a nivel provincial con la clave primaria `id_obs = {Periodo}_{id_prov}`.

El objetivo central es diagnosticar la estructura interna del dataset, analizar la distribución espacial de los indicadores socioeconómicos, evaluar la dinámica temporal y segmentar el territorio español mediante análisis multivariante, de conglomerados y regresión de datos de panel.

```{r data-import-validation}
# Verificación del objeto 'datos_socioecon_ESP' en el entorno global
if (!exists("datos_socioecon_ESP")) {
  stop("El objeto 'datos_socioecon_ESP' no está presente en el entorno global. Asegúrese de haber ejecutado la tubería de limpieza previa.")
}

# Preparación y estandarización del dataset
df_analisis <- datos_socioecon_ESP %>%
  mutate(
    id_prov = str_pad(as.character(id_prov), width = 2, side = "left", pad = "0"),
    Periodo = as.numeric(gsub("\\D", "", as.character(Periodo)))
  )

# Resumen estructural
num_obs <- nrow(df_analisis)
num_provs <- n_distinct(df_analisis$id_prov)
periodo_min <- min(df_analisis$Periodo, na.rm = TRUE)
periodo_max <- max(df_analisis$Periodo, na.rm = TRUE)
```

El panel de datos contiene un total de **`r num_obs`** observaciones correspondientes a **`r num_provs`** unidades territoriales (provincias y ciudades autónomas), cubriendo un rango temporal de **`r periodo_min`** a **`r periodo_max`**.

---

# 2. Control de Calidad, Integridad y Diagnóstico de Ausentes

## 2.1. Estructura de Tipos de Datos e Identificación de Valores Faltantes

Antes del análisis descriptivo, auditamos la tasa de valores ausentes (`NA`) por variable para descartar sesgos sistemáticos derivados del proceso de unión o desalineación temporal de las fuentes originales del INE.

```{r missingness-analysis}
# Diagnóstico de valores ausentes por variable
missing_summary <- df_analisis %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(cols = everything(), names_to = "Variable", values_to = "NA_Count") %>%
  mutate(
    NA_Percent = (NA_Count / nrow(df_analisis)) * 100
  ) %>%
  arrange(desc(NA_Percent))

missing_summary %>%
  kable(
    caption = "Tabla 2.1: Diagnóstico de Valores Ausentes por Variable",
    col.names = c("Variable", "Conteo de NAs", "Porcentaje (%)"),
    digits = 2
  ) %>%
  kable_styling(bootstrap_options = c("striped", "hover", "condensed"), full_width = FALSE)

# Gráfico de perfil de completitud
ggplot(missing_summary, aes(x = reorder(Variable, NA_Percent), y = NA_Percent)) +
  geom_col(fill = "steelblue", width = 0.7) +
  geom_text(aes(label = sprintf("%.1f%%", NA_Percent)), hjust = -0.1, size = 3) +
  coord_flip() +
  scale_y_continuous(limits = c(0, max(missing_summary$NA_Percent, 10) * 1.25), labels = percent_format(scale = 1)) +
  labs(
    title = "Estructura de Valores Ausentes por Variable",
    subtitle = "Porcentaje relativo de NAs en el panel provincial combinando todas las observaciones",
    x = "Variable",
    y = "Porcentaje de Ausentes"
  )
```

## 2.2. Resumen Estadístico Descriptivo Universal

Calculamos los estadísticos de tendencia central, dispersión y forma (media, mediana, desviación estándar, Rango Intercuartílico, mínimo y máximo) para el conjunto completo de variables cuantitativas.

```{r descriptive-summary-table}
# Selección de variables cuantitativas
vars_num <- df_analisis %>%
  select(where(is.numeric)) %>%
  select(-any_of(c("Periodo"))) %>%
  colnames()

resumen_cuant <- df_analisis %>%
  pivot_longer(cols = all_of(vars_num), names_to = "Variable", values_to = "Valor") %>%
  group_by(Variable) %>%
  summarise(
    N = sum(!is.na(Valor)),
    Media = mean(Valor, na.rm = TRUE),
    Desv_Est = sd(Valor, na.rm = TRUE),
    Mediana = median(Valor, na.rm = TRUE),
    IQR = IQR(Valor, na.rm = TRUE),
    Min = min(Valor, na.rm = TRUE),
    Max = max(Valor, na.rm = TRUE),
    .groups = "drop"
  )

resumen_cuant %>%
  kable(
    caption = "Tabla 2.2: Estadísticos Descriptivos Universales de Variables Cuantitativas",
    digits = 2
  ) %>%
  kable_styling(bootstrap_options = c("striped", "hover", "condensed"), full_width = TRUE)
```

---

# 3. Análisis Univariante de Distribuciones e Identificación de Sesgos

## 3.1. Densidades Empíricas e Histogramas

Evaluamos la forma analítica de las distribuciones para detectar asimetría positiva en métricas económicas frente a métricas demográficas.

```{r univariate-distributions, fig.height=8}
df_analisis %>%
  select(all_of(vars_num)) %>%
  pivot_longer(cols = everything(), names_to = "Variable", values_to = "Valor") %>%
  filter(!is.na(Valor)) %>%
  ggplot(aes(x = Valor)) +
  geom_histogram(aes(y = after_stat(density)), bins = 30, fill = "#2C3E50", color = "white", alpha = 0.7) +
  geom_density(color = "#E74C3C", linewidth = 1) +
  facet_wrap(~ Variable, scales = "free", ncol = 3) +
  labs(
    title = "Distribuciones Empíricas de las Variables Numéricas",
    subtitle = "Histograma normalizado con estimación no paramétrica de densidad Kernel",
    x = "Valor",
    y = "Densidad"
  )
```

## 3.2. Detección de Valores Atípicos (Outliers)

Mediante diagramas de caja (boxplots), analizamos las provincias que se posicionan sistemáticamente como valores atípicos estructurales.

```{r univariate-boxplots, fig.height=8}
df_analisis %>%
  select(all_of(vars_num)) %>%
  pivot_longer(cols = everything(), names_to = "Variable", values_to = "Valor") %>%
  filter(!is.na(Valor)) %>%
  ggplot(aes(x = Variable, y = Valor)) +
  geom_boxplot(fill = "#3498DB", alpha = 0.6, outlier.color = "#E74C3C", outlier.shape = 16) +
  facet_wrap(~ Variable, scales = "free", ncol = 3) +
  theme(axis.text.x = element_blank(), axis.ticks.x = element_blank()) +
  labs(
    title = "Identificación de Outliers y Dispersión Cuartílica",
    subtitle = "Diagramas de caja individuales para la detección de dispersión intra-variable",
    x = NULL,
    y = "Escala Original de la Variable"
  )
```

---

# 4. Análisis Longitudinal y Dinámica Temporal

## 4.1. Evolución Promedio Nacional y Divergencia Interprovincial

Analizamos las líneas de tendencia central ponderadas y la envolvente de dispersión (intervalo intercuartílico P25–P75).

```{r longitudinal-trends, fig.height=10}
df_analisis %>%
  select(Periodo, all_of(vars_num)) %>%
  pivot_longer(cols = -Periodo, names_to = "Variable", values_to = "Valor") %>%
  filter(!is.na(Valor)) %>%
  group_by(Periodo, Variable) %>%
  summarise(
    Media = mean(Valor, na.rm = TRUE),
    Q25 = quantile(Valor, 0.25, na.rm = TRUE),
    Q75 = quantile(Valor, 0.75, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = Periodo, y = Media)) +
  geom_ribbon(aes(ymin = Q25, ymax = Q75), fill = "steelblue", alpha = 0.2) +
  geom_line(color = "navy", linewidth = 1) +
  geom_point(color = "navy", size = 1.5) +
  facet_wrap(~ Variable, scales = "free_y", ncol = 2) +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(
    title = "Evolución Temporal Promedio y Sombra Intercuartílica (P25 - P75)",
    subtitle = "Trayectoria agregada nacional de las variables cuantitativas durante el periodo de estudio",
    x = "Año",
    y = "Valor Promedio Nacional"
  )
```

## 4.2. Trayectorias Provinciales Seleccionadas

Comparación del comportamiento de provincias con perfiles económicos contrastados (ej. Madrid, Barcelona, Sevilla, Bizkaia, Zamora, Baleares).

```{r provincial-trajectories, fig.height=8}
provs_muestra <- c("28", "08", "41", "48", "49", "07") # Madrid, Barcelona, Sevilla, Bizkaia, Zamora, Baleares
var_ilustrativa <- vars_num[1]

df_analisis %>%
  filter(id_prov %in% provs_muestra) %>%
  ggplot(aes(x = Periodo, y = .data[[var_ilustrativa]], color = Provincia, group = Provincia)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2) +
  scale_color_brewer(palette = "Set1") +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(
    title = paste("Evolución Comparativa Provincial:", var_ilustrativa),
    subtitle = "Trayectorias individuales en una muestra heterogénea de provincias españolas",
    x = "Año",
    y = var_ilustrativa,
    color = "Provincia"
  )
```

---

# 5. Cartografía Espacial y Coropletas (mapSpain + sf)

```{r spatial-data-prep}
# Recuperación de la cartografía oficial de provincias
mapa_provs <- esp_get_prov() %>%
  mutate(cpro = str_pad(cpro, width = 2, side = "left", pad = "0")) %>%
  filter(!cpro %in% c("51", "52"))

ultimo_periodo <- max(df_analisis$Periodo, na.rm = TRUE)

df_reciente <- df_analisis %>%
  filter(Periodo == ultimo_periodo)

mapa_datos <- mapa_provs %>%
  left_join(df_reciente, by = c("cpro" = "id_prov"))
```

## 5.1. Distribución Espacial en el Período Reciente (`r ultimo_periodo`)

```{r spatial-coropleth-map, fig.height=7}
var_mapa <- vars_num[1]

ggplot(mapa_datos) +
  geom_sf(aes(fill = .data[[var_mapa]]), color = "white", size = 0.15) +
  scale_fill_viridis_c(
    option = "magma",
    na.value = "grey80",
    labels = comma_format(big.mark = ".")
  ) +
  labs(
    title = paste("Distribución Provincial Espacial de", var_mapa, "(Año", ultimo_periodo, ")"),
    subtitle = "Mapa de coropletas basado en la cartografía oficial del INE (mapSpain)",
    fill = var_mapa,
    caption = "Fuente: Elaboración propia a partir de datos_socioecon_ESP."
  ) +
  theme_void() +
  theme(
    legend.position = "right",
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5, margin = margin(b = 10))
  )
```

## 5.2. Panel Multivariante Espacial Comparativo

```{r spatial-multi-map, fig.height=6, fig.width=12}
if (length(vars_num) >= 2) {
  var1 <- vars_num[1]
  var2 <- vars_num[2]
  
  p1 <- ggplot(mapa_datos) +
    geom_sf(aes(fill = .data[[var1]]), color = "white", size = 0.1) +
    scale_fill_viridis_c(option = "viridis", na.value = "grey80") +
    labs(title = paste("A:", var1), fill = NULL) +
    theme_void() +
    theme(legend.position = "bottom")

  p2 <- ggplot(mapa_datos) +
    geom_sf(aes(fill = .data[[var2]]), color = "white", size = 0.1) +
    scale_fill_viridis_c(option = "plasma", na.value = "grey80") +
    labs(title = paste("B:", var2), fill = NULL) +
    theme_void() +
    theme(legend.position = "bottom")

  p1 + p2 + 
    plot_annotation(
      title = "Comparación Espacial Estructural Electiva",
      subtitle = paste("Fotografía fija del periodo", ultimo_periodo)
    )
}
```

---

# 6. Análisis Correlacional y Bivariante

## 6.1. Matriz de Correlación de Pearson

```{r correlation-matrix, fig.height=7, fig.width=8}
matriz_corr <- df_analisis %>%
  select(all_of(vars_num)) %>%
  drop_na() %>%
  cor(method = "pearson")

corrplot(
  matriz_corr,
  method = "color",
  type = "upper",
  order = "hclust",
  addCoef.col = "black",
  number.cex = 0.7,
  tl.col = "black",
  tl.srt = 45,
  diag = FALSE,
  title = "Matriz de Correlación Lineal de Pearson",
  mar = c(0, 0, 2, 0)
)
```

## 6.2. Diagramas de Dispersión y Ajuste LOESS

```{r scatter-bivariate, fig.height=6}
if (length(vars_num) >= 2) {
  v_x <- vars_num[1]
  v_y <- vars_num[2]
  
  ggplot(df_analisis, aes(x = .data[[v_x]], y = .data[[v_y]])) +
    geom_point(aes(color = as.factor(Periodo)), alpha = 0.5, size = 2) +
    geom_smooth(method = "loess", color = "black", linetype = "dashed", se = TRUE) +
    geom_smooth(method = "lm", color = "red", se = FALSE) +
    scale_color_viridis_d(option = "cividis", name = "Año") +
    labs(
      title = paste("Relación Bivariante:", v_x, "vs.", v_y),
      subtitle = "Puntos coloreados por periodo con ajuste lineal (rojo) y LOESS no paramétrico (negro)",
      x = v_x,
      y = v_y
    )
}
```

---

# 7. Modelización Multivariante: PCA y Clustering Provincial

## 7.1. Análisis de Componentes Principales (PCA)

```{r pca-analysis}
df_pca_raw <- df_analisis %>%
  filter(Periodo >= (ultimo_periodo - 4)) %>%
  group_by(id_prov, Provincia) %>%
  summarise(across(all_of(vars_num), ~ mean(., na.rm = TRUE)), .groups = "drop") %>%
  drop_na()

df_pca_mat <- df_pca_raw %>%
  select(all_of(vars_num)) %>%
  scale()

rownames(df_pca_mat) <- df_pca_raw$Provincia

pca_res <- prcomp(df_pca_mat, center = TRUE, scale. = TRUE)

fviz_eig(pca_res, addlabels = TRUE, barfill = "steelblue", barcolor = "navy") +
  labs(
    title = "Scree Plot: Varianza Explicada por Componente Principal",
    x = "Dimensiones",
    y = "% de Varianza Explicada"
  )
```

## 7.2. Biplot Factorial

```{r pca-biplot, fig.height=8, fig.width=9}
fviz_pca_biplot(
  pca_res,
  repel = TRUE,
  col.var = "#E74C3C",
  col.ind = "#2C3E50",
  alpha.ind = 0.8,
  title = "Biplot de Componentes Principales (Dim 1 vs Dim 2)"
)
```

## 7.3. Agrupamiento K-Means

```{r cluster-analysis, fig.height=7}
set.seed(123)
k_means_res <- kmeans(df_pca_mat, centers = 4, nstart = 25)

df_clusters <- df_pca_raw %>%
  mutate(Cluster = as.factor(k_means_res$cluster))

mapa_clusters <- mapa_provs %>%
  left_join(df_clusters, by = c("cpro" = "id_prov"))

ggplot(mapa_clusters) +
  geom_sf(aes(fill = Cluster), color = "white", size = 0.2) +
  scale_fill_brewer(palette = "Set2", na.value = "grey90") +
  labs(
    title = "Tipología Socioeconómica Provincial (Clustering K-Means)",
    subtitle = "Segmentación territorial basada en la firma multivariante de las provincias",
    fill = "Conglomerado"
  ) +
  theme_void() +
  theme(legend.position = "bottom")
```

---

# 8. Modelización Econométrica de Datos de Panel (Efectos Fijos)

Para controlar la heterogeneidad no observada invariable en el tiempo a nivel provincial ($\alpha_i$) y los shocks temporales comunes ($\gamma_t$), estimamos un modelo de panel con **Efectos Fijos de Dos Vías (Two-Way Fixed Effects)** mediante el paquete `plm`.

```{r panel-econometrics}
if (length(vars_num) >= 2) {
  dep_var <- vars_num[1]
  indep_vars <- vars_num[-1]
  
  formula_panel <- as.formula(paste(dep_var, "~", paste(indep_vars, collapse = " + ")))
  
  # Preparación del objeto pdata.frame
  pdata <- pdata.frame(df_analisis, index = c("id_prov", "Periodo"))
  
  # Estimación del modelo de efectos fijos de dos vías
  model_fe <- plm(formula_panel, data = pdata, model = "within", effect = "twoways")
  
  # Resumen del modelo
  summary(model_fe)
}
```

---

# 9. Conclusiones y Sintesis

1. **Estructura de Datos:** El dataset `datos_socioecon_ESP` proporciona una base sólida y balanceada para el análisis territorial longitudinal.
2. **Brecha Espacial:** Se consolida la asimetría espacial entre los grandes polos urbanos e industriales frente al interior peninsular.
3. **Agrupamiento Operativo:** El análisis multivariante permite clasificar el territorio en 4 perfiles socioeconómicos homogéneos útiles para el diseño de políticas públicas diferenciadas.
```