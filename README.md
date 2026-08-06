# scaleLLMflow

Subproyecto de libreria R para generalizar el flujo de evaluacion de escalas mediante LLMs.

La libreria organiza prompts entrenados por escala y modelo:

```text
inst/scales/
  mqs/
    gemini-2.5-flash/
      prompt.txt
      metadata.json
    gemini-flash/
      prompt.txt
      metadata.json
    generic/
      prompt.txt
      metadata.json
```

Cada subcarpeta de modelo representa un prompt entrenado/validado con un dataset concreto. Si se pide un modelo sin prompt exacto, `resolve_prompt()` busca el prompt mas cercano:

1. modelo exacto;
2. misma familia textual, por ejemplo `flash`;
3. coincidencia por version numerica;
4. prompt `generic`;
5. mayor similitud de nombre disponible.

Las claves API son siempre del usuario y se leen del entorno. No se guardan claves en la libreria.

Variables esperadas:

- `GEMINI_API_KEY` o `GOOGLE_GEMINI_KEY`
- `OPENAI_API_KEY`
- `OPENAI_PROJECT_ID`, opcional

## Instalacion local

Desde la raiz del repo:

```powershell
R CMD INSTALL "library/scaleLLMflow"
```

O durante desarrollo:

```r
devtools::load_all("library/scaleLLMflow")
```

## Uso basico

```r
library(scaleLLMflow)

available_scales()
available_models("mqs")

result <- run_article(
  article_path = "data/pdf/training_set1/2004 Miller.pdf",
  scale = "mqs",
  provider = "gemini",
  model = "gemini-2.5-flash",
  filetype = "pdf"
)

result$scores
```

Ejecutar un directorio completo:

```r
results <- run_dataset(
  articles_dir = "data/pdf/training_set2",
  scale = "mqs",
  provider = "gemini",
  model = "gemini-2.5-flash",
  output_dir = "resultados/set2_library_run",
  filetype = "pdf"
)
```

`filetype` puede ser `pdf`, `txt`, `md` o `auto`. Con `auto`, la libreria analiza todos los ficheros `.pdf`, `.txt` y `.md` de la carpeta.

## Anadir una escala nueva

Crear:

```text
inst/scales/<nombre_escala>/<modelo>/prompt.txt
inst/scales/<nombre_escala>/<modelo>/metadata.json
```

El prompt debe incluir la definicion de la escala, reglas de puntuacion y formato de salida esperado. La libreria anade automaticamente el texto del articulo al final de la peticion.

## Politica de claves API

La libreria nunca incluye claves API. Cada usuario debe configurar sus credenciales en `.Renviron`, variables de entorno del sistema, RStudio, o pasar `api_key` en memoria durante una llamada concreta. Las variables leidas son:

- Gemini: `GEMINI_API_KEY` o `GOOGLE_GEMINI_KEY`
- OpenAI/ChatGPT: `OPENAI_API_KEY`
- OpenAI project opcional: `OPENAI_PROJECT_ID`
