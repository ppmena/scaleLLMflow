# scaleLLMflow — auditoría de código

Fecha de auditoría: 2026-10-18  
Versión inspeccionada: 0.4.2

## Alcance y método

Se inspeccionaron `DESCRIPTION`, `NAMESPACE`, `README.md`, todos los archivos de
`R/`, los registros de `inst/scales/`, la documentación `man/`, los ejemplos y
los tests existentes. Se ejecutaron comprobaciones estáticas y se intentó
ejecutar `testthat` y `R CMD check`. La ruta original contiene un carácter
acentuado que la sesión R configurada en ASCII no puede representar; las
comprobaciones dinámicas deben repetirse desde una ruta DOS corta o una ruta
sin caracteres no ASCII.

## Hallazgos

| ID | Severidad | Archivo | Función | Problema | Evidencia | Solución |
|---|---|---|---|---|---|---|
| API-01 | Alta | `README.md` | Inicio rápido | El README invocaba `available_models(scale=...)`, función que no existe ni está exportada. | `NAMESPACE` exporta `available_provider_models()` y `rg` no encuentra `available_models`. | Se sustituyó el ejemplo por `available_provider_models("my_provider")`. |
| VAL-01 | Alta | `R/parse.R` | `validate_scale_response()` | Se comprobaban ítems obligatorios, pero se aceptaban ítems no definidos; además JSON con claves duplicadas podía quedar reducido silenciosamente por el parser. | El código solo calculaba `missing <- setdiff(...)` y no comprobaba extras/duplicados. | Se rechazan ítems adicionales y se detectan claves repetidas en el objeto `items`. |
| DATA-01 | Alta | `R/workflow.R` | `run_dataset()` | Dos archivos distintos podían producir el mismo ID tras quitar extensión y reemplazar espacios, mezclando resultados. | `clean_article_id()` no comprobaba colisiones. | Se detectan y rechazan colisiones antes de iniciar llamadas al proveedor. |
| PDF-01 | Alta | `R/text.R` | `extract_pdf_text()` | Una extracción PDF vacía podía continuar como si fuera válida. | Se concatenaba el resultado de `pdf_text()` sin comprobar contenido. | Se capturan errores de extracción y se rechaza texto vacío. |
| IO-01 | Media | `R/text.R` | Caché Markdown | La caché se escribía directamente; una interrupción podía dejar un archivo parcial. | `writeLines()` apuntaba directamente al destino. | Escritura temporal y sustitución posterior. |
| TRACE-01 | Media | `R/workflow.R` | `build_provenance()` | La auditoría no tenía un identificador de ejecución explícito ni estado de validación. | El registro contenía hashes, pero no `run_id`/`validation_status`. | Se añadieron ambos campos manteniendo los metadatos anteriores. |
| SEC-01 | Media | `R/text.R` | `build_scale_prompt()` | El artículo se delimitaba, pero no se indicaba explícitamente que su contenido era no confiable. | El texto del documento se concatenaba directamente tras el prompt. | Se añadió una instrucción de separación de autoridad y delimitadores explícitos. |
| META-01 | Baja | `DESCRIPTION` | Metadatos | `Author` y `Maintainer` duplicaban información ya derivable de `Authors@R`. | Ambos campos coexistían con `Authors@R`. | Se eliminaron los campos redundantes. |

## Riesgos potenciales y pendientes

- La detección de duplicados JSON se limita al objeto `items` del contrato
  registrado; no pretende ser un parser JSON general.
- El proveedor no siempre comunica el identificador real del modelo; por ello
  `model_used` no puede afirmarse cuando la API no lo devuelve.
- `run_dataset()` sigue creando una carpeta nueva por ejecución. La lógica
  anterior de reutilización de logs solo era efectiva si un log ya existía en
  la carpeta recién creada; no se ha presentado como reanudación completa.
- La extracción de PDF no demuestra que el orden de lectura sea científicamente
  fiel; eso requiere revisión de documentos y, cuando proceda, conversión LLM.
- La validación estructural no demuestra concordancia empírica ni validez
  científica de una escala.

## Comportamientos que requieren validación científica

No se modificaron ítems, valores permitidos, reglas de total ni codificaciones
de las escalas MQS, PEDro o RoB 2. Deben seguir validándose por expertos:

- la interpretación de la evidencia extraída;
- las decisiones de cada escala en casos límite;
- la equivalencia entre prompts y versiones de modelos;
- la concordancia con evaluadores humanos y la validez externa.

## Estado de las comprobaciones

- `testthat::test_dir("tests/testthat")`: superado; 3 archivos de tests, sin
  fallos. El entorno produjo advertencias repetidas porque `LC_ALL=C.UTF-8`
  no puede cambiarse en esta instalación de Windows.
- `R CMD INSTALL`: superado desde una ruta DOS corta.
- `R CMD check --no-manual --no-vignettes`: no limpio. La instalación y carga
  del paquete superan las fases correspondientes, pero el check termina con
  1 error, 2 warnings y 1 note asociados a la comprobación de metadatos y a
  archivos históricos/nombres no portables del árbol de ejemplos. No se
  declara `R CMD check` superado.
- La ruta original con `Ó` impide ejecutar R directamente desde ella en este
  entorno; las comprobaciones dinámicas se realizaron desde `C:\slfcheck`.
