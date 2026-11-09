ENTREGA DEL PROYECTO AED

Contenido principal
- ProyectoAED.Rmd: informe reproducible en formato MDPI.
- Utilidades.Rmd: funciones y configuraciones reutilizables.
- codigo_extraido.R: código R generado desde Utilidades.Rmd.
- data/raw: ficheros originales utilizados por el análisis.
- data: ficheros procesados que también genera el informe.
- ProyectoAED.pdf: informe compilado.
- EnlaceRepo.txt: enlace al repositorio del proyecto.

Compilación desde esta carpeta

1. Abrir ProyectoAED.Rproj en RStudio o establecer esta carpeta como directorio de trabajo.
2. Ejecutar instalar_paquetes.R si alguna librería no está disponible.
3. Ejecutar:

   rmarkdown::render("ProyectoAED.Rmd", output_file = "ProyectoAED.pdf")

La plantilla lee los datos desde data/raw, por lo que no depende de rutas del ordenador de los autores.
Si falta algún fichero original, intentará descargarlo desde su fuente pública.