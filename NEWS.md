# scaleLLMflow (unreleased)

# scaleLLMflow 0.4.3

## Stabilization and documentation

- Moved prompt resolution, article discovery, and identifier-collision checks
  ahead of dataset output creation, so invalid runs do not leave partial output
  directories.
- Reused one validated structured response throughout single-article scoring,
  evidence extraction, and reference comparison.
- Normalized bundled article filenames to portable ASCII-compatible names.
- Added package-build exclusions for local caches, generated reports, and
  development-only files.
- Expanded the user documentation, Spanish getting-started guide, examples,
  troubleshooting notes, and release verification report.

## Auditoría y robustez

- Corregido el ejemplo de descubrimiento de modelos del README.
- La validación estructurada rechaza ítems no definidos y claves de ítems
  duplicadas.
- `run_dataset()` detecta colisiones de identificadores antes de procesar
  documentos.
- La extracción PDF falla explícitamente ante errores o texto vacío y la caché
  Markdown se escribe mediante un archivo temporal.
- La trazabilidad incorpora `run_id` y `validation_status`.
- El texto del artículo se marca como material no confiable al construir el
  prompt.
- Añadido `docs/CODE_AUDIT.md` y workflow de GitHub Actions para `R CMD check`.

# scaleLLMflow 0.4.2

## Provider rate-limit handling

HTTP 429 retries now honor provider `Retry-After` headers and retry hints in
response bodies, with capped exponential backoff up to 15 minutes.

# scaleLLMflow 0.4.1

## RoB 2 scale registry

Adds the Cochrane RoB 2 parallel-trial risk-of-bias prompt as a provider-neutral
scale-level registry entry. The flat-line categorical response is validated and
retained in evidence/audit output, with stable internal encoding for reports.

# scaleLLMflow 0.4.0

## First stable release

`scaleLLMflow` provides a general framework for applying scientific rating
scales to research articles with large language models. It supports article
text extraction and Markdown conversion, scale-specific prompt registries,
structured response validation, scoring, evidence capture, retries, audit
logs, dataset workflows, prompt training, and comparison of model outputs.

The release includes Gemini, OpenAI, and Claude integrations, provider-neutral
prompts with strict version control, MQS and PEDro scale definitions, GPT-5.6
reasoning configuration, and documentation and examples for local R/RStudio
use.
