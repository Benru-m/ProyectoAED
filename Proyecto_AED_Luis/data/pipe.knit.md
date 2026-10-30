---
title: "pipe"
author: "Luis Molina Villar"
date: "2026-10-28"
output: html_document
---





Este archivo carga y transforma los datos en crudo para obtener los conjuntos
de datos que se utilizarán en el análisis.

Para empezar, tenemos las funciones comunes al tratamiento de todos los datos. La primera función nos servirá para generar un id común a cada instancia (observación de cierta variable en un año y una provincia), que nos permitirá unir correctamente todas las tablas de datos con las que queramos trabajar.

``` r
# Función para generar el ID único
generar_id_obs <- function(df, col_anyo, col_prov) {
  df %>%
    mutate(
      id = paste0(
        as.numeric({{ col_anyo }}),
        "_",
        str_pad(as.character({{ col_prov }}), width = 2, side = "left", pad = "0")
      )
    )
}
# Mapeo entre nombre de provincias y códigos, todos los oficiales y usados por el INE
ine_provincias <- tibble::tribble(
  ~id_prov, ~Provincia_clean,
  "01", "Araba/Álava",
  "02", "Albacete",
  "03", "Alicante/Alacant",
  "04", "Almería",
  "05", "Ávila",
  "06", "Badajoz",
  "07", "Balears, Illes",
  "08", "Barcelona",
  "09", "Burgos",
  "10", "Cáceres",
  "11", "Cádiz",
  "12", "Castellón/Castelló",
  "13", "Ciudad Real",
  "14", "Córdoba",
  "15", "Coruña, A",
  "16", "Cuenca",
  "17", "Girona",
  "18", "Granada",
  "19", "Guadalajara",
  "20", "Gipuzkoa",
  "21", "Huelva",
  "22", "Huesca",
  "23", "Jaén",
  "24", "León",
  "25", "Lleida",
  "26", "Rioja, La",
  "27", "Lugo",
  "28", "Madrid",
  "29", "Málaga",
  "30", "Murcia",
  "31", "Navarra",
  "32", "Ourense",
  "33", "Asturias",
  "34", "Palencia",
  "35", "Palmas, Las",
  "36", "Pontevedra",
  "37", "Salamanca",
  "38", "Santa Cruz de Tenerife",
  "39", "Cantabria",
  "40", "Segovia",
  "41", "Sevilla",
  "42", "Soria",
  "43", "Tarragona",
  "44", "Teruel",
  "45", "Toledo",
  "46", "Valencia/València",
  "47", "Valladolid",
  "48", "Bizkaia",
  "49", "Zamora",
  "50", "Zaragoza",
  "51", "Ceuta",
  "52", "Melilla"
)

filtrar_provincias <- function(df) {
  df %>%
    mutate(id_prov = str_pad(as.character(id_prov), width = 2, side = "left", pad = "0")) %>%
    filter(id_prov %in% ine_provincias$id_prov)
}
```



## Carga de los datos en R
Se emplean únicamente funciones de base R. La función auxiliar lee los
ficheros mediante `readLines()` y después los transforma con `read.table()`.
También elimina el marcador BOM que aparece al principio de algunos ficheros.


``` r
leer_base <- function(fichero, separador) {
  readr::read_delim(
    file = fichero,
    delim = separador,
    locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
    na = c("", "NA", "null",".."),
    name_repair = "minimal",
    show_col_types = FALSE,
    progress = FALSE
  )
}

coste_vivienda <- leer_base("raw/coste_vivienda.csv", ";")
distr_pobl <- leer_base("raw/distribucion_poblacional.csv", "\t")
edad_maternidad <- leer_base("raw/edad_maternidad.csv", "\t")
migracion_interior <- leer_base("raw/migracion_interior.csv", "\t")
ocupacion_sector <- leer_base("raw/Ocupados_Sector_Provincia.csv", "\t")
pib_per_capita <- leer_base("raw/pib_per_capita.csv", ";")
renta_bruta_media <- leer_base("raw/renta_bruta_media.csv", "\t")
valor_bruto_sector <- leer_base("raw/valor_bruto_sector.csv", "\t")

# Normalizamos nombres problemáticos antes de usarlos en expresiones de R.
# Esto evita errores de codificación con tildes y deja una clave temporal común.
names(coste_vivienda)[1] <- "Periodo"
names(coste_vivienda)[4] <- "Regimen"
names(coste_vivienda)[7] <- "Comunidad_Autonoma"
```


Ahora vamos a preparar cada una de las tablas para poder unirlas en una tabla final que contenga los datos que deseamos.


## Preparación Coste Vivienda
Para empezar, eliminamos las columnas `Comunidad_Autónoma` y `CODAUTO`, ya que no nos interesan.

``` r
coste_vivienda$CODAUTO <- NULL
coste_vivienda$Comunidad_Autonoma <- NULL
```

Renombramos la columna `CPRO` como `id_prov`, la ponemos como primera columna de la tabla (este y el año serán los identificadores que usaremos para unir las distintas tablas), y reordenamos las filas para que estén en orden. Finalmente asignamos un id a cada instancia.

``` r
colnames(coste_vivienda)[5]<- "id_prov"
coste_vivienda <- filtrar_provincias(coste_vivienda)
coste_vivienda <- coste_vivienda %>% arrange(id_prov) %>% arrange(Periodo)
coste_vivienda <- coste_vivienda[c(5,6,1,2,3,4)]

coste_vivienda <- generar_id_obs(coste_vivienda,col_anyo = coste_vivienda$Periodo, col_prov = coste_vivienda$id_prov)
```

Los datos son trimestrales, pero nuestro análisis es anual, y no diferenciará entre vivienda libre y protegida, por lo que agregamos los datos por id usando el valor medio, cosa que ahora podemos hacer sin dificultad, al disponer de un id para cada instancia.

``` r
coste_vivienda <- coste_vivienda %>% group_by(id) %>% mutate(Precio_m2 = mean(Valor, na.rm = TRUE)) %>% ungroup() %>%select(-Valor, -Trimestre,-Regimen) %>%  distinct()
```

Nos quedamos solo con el valor del metro cuadrado y el id de la instancia.

``` r
coste_vivienda <- coste_vivienda %>% select(id,Precio_m2)
```

## Preparación de la distribución poblacional
Empezamos separando la columna provincias, en el nombre y el código de la provincia, una ve que las instancias que contenían una provincia se les ha asignado un número, eliminamos el resto de instancias (Total nacional,CCAA's), ordenamos los datos por orden alfabético (provincia) y temporal (año),  nos quedamos solo con los valores totales (olvidando los valores por sexo), y eliminamos la columna sexo.

``` r
distr_pobl <- distr_pobl %>% separate(
    col = Provincias,                   
    into = c("id_prov", "Provincia"), 
    sep = " ",                             
    extra = "merge"                        
  ) %>% filtrar_provincias() %>% arrange(id_prov,Periodo) %>% filter(Sexo=="Total") %>% select(-Sexo) %>% rename(Habitantes = Total)
```

```
## Warning: Expected 2 pieces. Missing pieces filled with `NA` in 78 rows [1, 2, 3, 4, 5,
## 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, ...].
```

``` r
distr_pobl <- generar_id_obs(distr_pobl,col_anyo = distr_pobl$Periodo, col_prov = distr_pobl$id_prov)
```

Nos quedamos con el id, y el valor de la población.

``` r
distr_pobl <- distr_pobl %>% select(id,Habitantes)
```

## Preparación de edad_maternidad

Este dataset tiene una estructura similar a la anterior, por lo que el proceso seguido es el mismo, solo que seleccionamos el valor total olvidándonos del orden de nacimiento (primer hijo/a,...), en vez de olvidarnos del sexo. Cambiamos el nombre de una column a para evitar problemas a la hora de trabajar con ella. 

``` r
colnames(edad_maternidad)[2] <- "Orden_de_nacimiento" 
edad_maternidad <- edad_maternidad %>% filter(Orden_de_nacimiento=="Todos")%>%separate(
    col = Provincias,                   
    into = c("id_prov", "Provincia"), 
    sep = " ",                             
    extra = "merge"                        
  ) %>% filtrar_provincias() %>% arrange(id_prov,Periodo) %>%
  select(-Orden_de_nacimiento) %>%
  mutate(
    Total = if (is.numeric(Total)) {
      as.numeric(Total)
    } else {
      readr::parse_number(
        as.character(Total),
        na = c("", "NA", "null", ".."),
        locale = readr::locale(decimal_mark = ",", grouping_mark = ".")
      )
    }
  ) %>%
  rename(Edad_Media_Maternidad = Total)

stopifnot(is.numeric(edad_maternidad$Edad_Media_Maternidad))

edad_maternidad <- generar_id_obs(edad_maternidad,col_anyo =edad_maternidad$Periodo, col_prov = edad_maternidad$id_prov)
```
Nos quedamos con el id y la edad media de maternidad

``` r
edad_maternidad <- edad_maternidad %>% select(id,Edad_Media_Maternidad)
```
## Preparacion de migración interior
Este dataset tiene una estructura similar a la anterior, por lo que el proceso seguido es el mismo, solo que seleccionamos el valor total por sexo, y nos quedamos con las edades 19-35.  Antes de filtrar por edad tenemos que transformar ese dato en un número, ya que viene expresada como `x Años`.


``` r
migracion_interior <- migracion_interior %>% filter(Sexo=="Ambos sexos")%>%separate(
    col = Provincias,                   
    into = c("id_prov", "Provincia"), 
    sep = " ",                             
    extra = "merge"                        
  )   %>% filtrar_provincias() %>% select(-Sexo) %>%mutate(Edad = parse_number(Edad))  %>% filter(Edad >= 19 & Edad <= 35) %>% select(-Edad)
```

```
## Warning: There was 1 warning in `mutate()`.
## i In argument: `Edad = parse_number(Edad)`.
## Caused by warning:
## ! 728 parsing failures.
## row col expected actual
##   1  -- a number  Total
##   2  -- a number  Total
##   3  -- a number  Total
##   4  -- a number  Total
##   5  -- a number  Total
## ... ... ........ ......
## See problems(...) for more details.
```

``` r
migracion_interior <- generar_id_obs(migracion_interior,col_anyo =migracion_interior$Periodo, col_prov = migracion_interior$id_prov)
  
migracion_interior <- migracion_interior %>%  group_by(id)%>%  
  mutate(Total = sum(Total, na.rm = TRUE)) %>% 
  ungroup()%>% distinct()%>%  arrange(id_prov,Periodo)  %>% rename(Migracion_Interior=Total)
```

Nos quedamos con el id y con la variable `Migracion_Interior`

``` r
migracion_interior <- migracion_interior %>% select(id,Migracion_Interior)
```
## Preparamos ocupacion_sector
Convertimos las columnas numçericas a números de forma segura con parse_number (readr). Separamos la columna provincias en nombre e índice. Cambiamos el valor `Construcción` por `Construccion` para evitar que el acento de errores, y expandimos los sectores como columnas, fusionando construcción e industria .En la columna trimestral sustituimos el trimestre por el año, ya que acabaremos agregando por año, y así podemos generar un id. Agregamos los datos de cada trimestre (diferenciando cada sector), teniendo en cuenta que la unidad del Total es miles de personas, y ordenamos los datos.

``` r
colnames(ocupacion_sector)[2]<-"sector_econ"
ocupacion_sector <- ocupacion_sector %>%
  mutate(sector_econ = ifelse(
    stringr::str_detect(stringr::str_to_lower(sector_econ), "^constru"),
    "Construccion",
    sector_econ
  ))%>%
  pivot_wider(names_from=sector_econ,values_from=Total)%>%
mutate(Industria = Industria + Construccion) %>% select(-Construccion)%>% distinct()%>%
  separate(
    col = Provincias,                   
    into = c("id_prov", "Provincia"), 
    sep = " ",                             
    extra = "merge"                        
  )   %>% filtrar_provincias() %>% mutate(Periodo = readr::parse_number(Periodo))

ocupacion_sector <- generar_id_obs(ocupacion_sector,col_anyo =ocupacion_sector$Periodo, col_prov = ocupacion_sector$id_prov)
  
ocupacion_sector <-ocupacion_sector %>%  group_by(id)%>%  
  mutate(Agricultura = mean(1000*Agricultura, na.rm = TRUE)) %>% 
  mutate(Servicios = mean(1000*Servicios, na.rm = TRUE)) %>%
  mutate(Industria = mean(1000*Industria, na.rm = TRUE)) %>%
  mutate(Total = mean(1000*Total, na.rm = TRUE)) %>%
  ungroup()%>% distinct()%>%  arrange(id_prov,Periodo)  
```
Nos quedamos con los sectores, y el id

``` r
ocupacion_sector <- ocupacion_sector %>% select(id,Agricultura,Industria,Servicios) %>% rename(Ocupados_Agricultura =Agricultura,Ocupados_Industria=Industria,Ocupados_Servicios=Servicios)
```


## Preparamos pib_per_capita
Separamos la columna Magnitud según sus valores, y nos quedamos solo con el valor Total. Extraemos las provincias, este dataset también incluye las CCAA's, para que no entren también, filtramos para deshacernos de los nombres que están en mayúsculas (considerando los que tienen al menos alguna minúscula). Asignamos el identificador único, y ordenamos los datos correctamente.

``` r
colnames(pib_per_capita)[1] <- "Provincias"
pib_per_capita <- pib_per_capita %>% pivot_wider(names_from=Magnitud,values_from = Total) %>% select(-4,-5) %>%
  separate(
    col = Provincias,                   
    into = c("id_prov", "Provincia"), 
    sep = " ",                             
    extra = "merge"                        
  )   %>% filtrar_provincias() %>% 
  filter(str_detect(Provincia, "[[:lower:]]"))

pib_per_capita <- generar_id_obs(pib_per_capita,col_anyo =pib_per_capita$Periodo, col_prov = pib_per_capita$id_prov)

pib_per_capita <- pib_per_capita %>% arrange(id_prov,Periodo) %>% rename(PIB_per_capita = Valor)
```
Nos quedamos con el id y el `pib_per_capita`

``` r
pib_per_capita <- pib_per_capita %>% select(id,PIB_per_capita)
```

## Preparamos renta_bruta
De la columna `Indicadores de rentas media`  nos quedamos solo con el valor `Renta bruta media por persona`, adaptando los nombres de los valores y columnas antes para evitar errores. Extraemos los valores numéricos de manera segura, y eliminamos las columnas cuya información no queremos. Le asignamos a las provincias un identificador numérico. Le asignamos un identificador único. Usamos el identificador para agragar los valores de cada instancia (ya que los valores de las islas venían separados).


``` r
colnames(renta_bruta_media)[1] <- "Total_Nacional"
colnames(renta_bruta_media)[5] <- "Indicadores"

renta_bruta_media <- renta_bruta_media %>% filter(Indicadores == "Renta bruta media por persona") %>%
  select(-Indicadores,-2,-1,-Islas) %>% rename(RentaBrutaMedia=Total) %>% filter(!is.na(Provincias), Provincias != "NA") %>% inner_join(ine_provincias, by = c("Provincias" = "Provincia_clean"))



renta_bruta_media <- generar_id_obs(renta_bruta_media,col_anyo =renta_bruta_media$Periodo, col_prov = renta_bruta_media$id_prov)

renta_bruta_media <- renta_bruta_media %>% group_by(id) %>%
    mutate(RentaBrutaMedia = mean(RentaBrutaMedia, na.rm = TRUE)) %>%
 ungroup() %>%
  distinct() %>% arrange(id_prov,Periodo) 
```
Nos quedamos con la `renta_bruta_media` y el id.

``` r
renta_bruta_media <- renta_bruta_media %>% select(id,RentaBrutaMedia)
```

## Preparando valor_bruto_sector
Empezamos separando la columna `Provincias` en nombre y número, y de las ramas de actividad nos deshacemos de `Impuestos netos sobre los productos`, del `Valor bruto añadido total`, y del `PRODUCTO INTERIOR BRUTO A PRECIOS DE MERCADO`. Separamos los sectores de actividad restantes en provincias, para poder asignar identificadores únicos, y  agrupamos en tres grandes sectores, primario, secundario y terciario.


``` r
colnames(valor_bruto_sector)[2] <- "Rama_Actividad"
sectores <- unique(valor_bruto_sector[[2]])

sector_primario <- c(sectores[[1]])
sector_secundario <- c(sectores[2:4])
sector_terciario <- c(sectores[5:7])

valor_bruto_sector <- valor_bruto_sector %>% separate(
    col = Provincias,                   
    into = c("id_prov", "Provincia"), 
    sep = " ",                             
    extra = "merge"                        
  )   %>% filtrar_provincias() %>% filter(Rama_Actividad != "Impuestos netos sobre los productos") %>%  filter(Rama_Actividad != "Valor añadido bruto total") %>%
  filter(Rama_Actividad != "PRODUCTO INTERIOR BRUTO A PRECIOS DE MERCADO") %>%
  pivot_wider(names_from = Rama_Actividad,values_from = Total) %>% mutate(Periodo = readr::parse_number(Periodo))

valor_bruto_sector <- generar_id_obs(valor_bruto_sector,col_anyo =valor_bruto_sector$Periodo, col_prov = valor_bruto_sector$id_prov)

valor_bruto_sector <- valor_bruto_sector %>% mutate(VAB_Secundario= rowSums(pick(all_of(sector_secundario)), na.rm = TRUE)) %>%
  select(-all_of(sector_secundario)) %>%  mutate(VAB_Terciario= rowSums(pick(all_of(sector_terciario)), na.rm = TRUE)) %>%
  select(-all_of(sector_terciario)) %>% rename(VAB_Primario=sector_primario)
```

```
## Warning: There were 2 warnings in `mutate()`.
## The first warning was:
## i In argument: `VAB_Secundario = rowSums(pick(all_of(sector_secundario)), na.rm
##   = TRUE)`.
## Caused by warning in `enexpr()`:
## ! unable to translate 'B_E. Industrias extractivas, industria manufacturera, suministro de energ<U+00ED>a el<U+00E9>ctrica, gas, vapor y aire acondicionado, suministro de agua, actividades de saneamiento, gesti<U+00F3>n de residuos y descontaminaci<U+00F3>n' to native encoding
## i Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
```

```
## Warning: There were 3 warnings in `mutate()`.
## The first warning was:
## i In argument: `VAB_Terciario = rowSums(pick(all_of(sector_terciario)), na.rm =
##   TRUE)`.
## Caused by warning in `enexpr()`:
## ! unable to translate 'G_J. Comercio al por mayor y al por menor, reparaci<U+00F3>n de veh<U+00ED>culos de motor y motocicletas, transporte y almacenamiento, hosteler<U+00ED>a, informaci<U+00F3>n y comunicaciones' to native encoding
## i Run `dplyr::last_dplyr_warnings()` to see the 2 remaining warnings.
```

```
## Warning: Using an external vector in selections was deprecated in tidyselect 1.1.0.
## i Please use `all_of()` or `any_of()` instead.
##   # Was:
##   data %>% select(sector_primario)
## 
##   # Now:
##   data %>% select(all_of(sector_primario))
## 
## See <https://tidyselect.r-lib.org/reference/faq-external-vector.html>.
## This warning is displayed once per session.
## Call `lifecycle::last_lifecycle_warnings()` to see where this warning was
## generated.
```
Nos quedamos con el id y el VAB de cada sector.

``` r
valor_bruto_sector <- valor_bruto_sector %>% select(id,VAB_Primario,VAB_Secundario,VAB_Terciario)
```


## Unimos todos los datos en una tabla y los guardamos

Ahora usamos el identificador único para unir los datos en una única tabla, y los guardamos en un fichero.

``` r
datos_socioecon_ESP <- coste_vivienda %>% full_join(distr_pobl,by="id") %>% full_join(edad_maternidad,by="id")%>% full_join(migracion_interior,by="id") %>% 
  full_join(ocupacion_sector,by="id") %>% full_join(pib_per_capita,by="id")%>% full_join(renta_bruta_media,by="id")%>% full_join(valor_bruto_sector,by="id")
```

Ahora que tenemos los datos unidos, separamos el id en año y provincia de cada observación, y a la provincia le asignamos el nombre.

``` r
codigos_vec <- deframe(ine_provincias)
datos_socioecon_ESP <- datos_socioecon_ESP %>% separate(id,c("Periodo","Provincia"),sep="_") %>%  mutate(Periodo = as.integer(Periodo), Provincia= codigos_vec[Provincia])
```
Guardamos los datos como `csv` y como `Rdata`

``` r
save(datos_socioecon_ESP,file = "Datos_SocioEcon.Rdata")
write_delim(datos_socioecon_ESP,file = "Datos_SocioEcon.csv",delim = ";")
```
