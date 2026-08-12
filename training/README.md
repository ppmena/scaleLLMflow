# Entrenamiento local de prompts para escalas

Esta carpeta contiene experimentos locales para mejorar prompts de escalas científicas mediante artículos con puntuaciones de referencia. El objetivo es ajustar el comportamiento del prompt en un conjunto de entrenamiento sin modificar el código de `scaleLLMflow` ni el registro oficial de la librería.

## Estructura

Cada experimento puede organizarse así:

```text
training/
  training_<escala>_<numero>/
    articles/
    ideal.csv
    scales/<escala>/<provider>-generic/prompt.md
    scales/<escala>/<provider>-generic/metadata.json
    iterations/iteration_1/
    iterations/iteration_2/
    comparison.csv
    comparison_summary.csv
```

`articles/` contiene los documentos de entrenamiento. `ideal.csv` contiene las puntuaciones revisadas por una persona experta. Sus columnas deben identificar el artículo y los ítems de la escala; en MQS son `IT01` a `IT10`.

## Registro local

El prompt oficial se copia a la carpeta del experimento y se modifica únicamente allí. El registro local se utiliza mediante `registry_dir`:

```r
library(scaleLLMflow)

run <- run_dataset(
  articles_dir = "training/training_mqs_1/articles",
  scale = "mqs",
  provider = "openai",
  model = "gpt-4.1-mini",
  registry_dir = "training/training_mqs_1/scales",
  output_dir = "training/training_mqs_1/iterations/iteration_1",
  filetype = "pdf",
  temperature = 0,
  tables_advanced = TRUE
)
```

El paquete oficial permanece intacto. `metadata.json` debe conservar la definición formal de la escala y el esquema JSON; solo se actualiza localmente `prompt_version` cuando corresponda.

## Ciclo de entrenamiento

1. Copiar el prompt oficial y su `metadata.json` al registro local.
2. Ejecutar una primera iteración sin cambios o con cambios mínimos.
3. Comparar las puntuaciones con `ideal.csv` a nivel de ítem.
4. Leer las evidencias y razones de los errores.
5. Identificar el problema: evidencia ignorada, criterio demasiado amplio, confusión temporal o ambigüedad del ítem.
6. Modificar el prompt local con una regla clara y limitada.
7. Ejecutar otra iteración en una carpeta diferente.
8. Conservar la versión con mejor precisión y menor error sistemático.

Cada iteración debe conservar `prompt_used.md`, los `*_AuditLog.txt`, los informes CSV y los metadatos de reproducibilidad. No se deben sobrescribir resultados anteriores.

## Comparación

La librería incluye `compare_training_iterations()` para automatizar la
comparación de los informes producidos por `run_dataset()`:

```r
comparison <- compare_training_iterations(
  "training_mqs_1/ideal.csv",
  "training_mqs_1/iterations"
)
comparison$comparison
comparison$summary
```

La función busca el `*_Consensus_Report.csv` de cada carpeta
`iteration_N`, compara cada `Item_n` con las columnas `IT01`, `IT02`, etc. de la
clave y devuelve el detalle por ítem y el resumen de precisión.

La métrica principal es:

```text
precisión = ítems correctos / ítems totales
```

La comparación debe incluir `comparison.csv`, con iteración, artículo, ítem, puntuación obtenida, puntuación ideal y coincidencia, y `comparison_summary.csv`, con el resumen por iteración. También deben revisarse los errores repetidos, no solo la precisión global.

Se recomienda limitar el entrenamiento inicial a cuatro iteraciones. Si el resultado no mejora, hay que revisar si el modelo ignora instrucciones contradictorias, si la extracción PDF pierde evidencia, si `ideal.csv` es consistente o si el problema requiere otro modelo.

## Interpretación

Coincidir con `ideal.csv` demuestra ajuste al conjunto de entrenamiento, no validez científica general. El prompt final debe probarse con artículos nuevos, otro conjunto de referencia y revisión humana de las evidencias. Los ejemplos específicos del conjunto de entrenamiento deben marcarse como calibración experimental, no como reglas científicas universales.

## Confidencialidad

Los prompts, artículos y resultados pueden mantenerse en el proyecto local. Sin embargo, con Gemini, OpenAI o Claude el texto se envía al proveedor correspondiente. Un registro local no implica inferencia local; para ello haría falta un proveedor como Ollama o LM Studio.
