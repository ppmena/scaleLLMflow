# scaleLLMflow

`scaleLLMflow` is an R package for applying prompt-defined assessment scales to collections of PDF, TXT, or Markdown documents with an LLM.

The package provides the execution framework: document extraction, prompt resolution, provider calls, retries, structured-response validation, scoring, audit logs, and dataset reports. Each registered scale defines its own items, scoring rules, metadata, and response format.

## Installation

From a local checkout:

```powershell
R CMD build .
R CMD INSTALL scaleLLMflow_0.2.0.tar.gz
```

For development:

```r
devtools::load_all("path/to/scaleLLMflow")
```

The package requires R and the dependencies listed in `DESCRIPTION`. Tests use
`testthat`.

## Credentials

Credentials are supplied by the user and are never stored by the package.
Configure them in `.Renviron`, the system environment, RStudio, or pass an
API key in memory for a single call:

- Gemini: `GEMINI_API_KEY` or `GOOGLE_GEMINI_KEY`
- OpenAI: `OPENAI_API_KEY`
- Optional OpenAI project: `OPENAI_PROJECT_ID`
- Claude/Anthropic: `ANTHROPIC_API_KEY` or `CLAUDE_API_KEY`

## Quick start

```r
library(scaleLLMflow)

available_scales()

result <- run_article(
  article_path = "path/to/article.pdf",
  scale = "mqs",
  provider = "gemini",
  model = "gemini-3.6-flash",
  filetype = "pdf"
)

result$scores
result$total_score
```

To process a directory:

```r
results <- run_dataset(
  articles_dir = "path/to/articles",
  scale = "mqs",
  provider = "gemini",
  model = "gemini-3.6-flash",
  output_dir = "results",
  filetype = "auto"
)
```

`filetype` accepts `pdf`, `txt`, `md`, or `auto`. Dataset runs create a
timestamped subdirectory with scores, evidence, audit logs, and an errors file
when any document fails.

## Providers and models

Provider integrations are selected explicitly with `provider` and `model`.
The provider API determines which model identifiers are available; the prompt
registry does not attempt to maintain a static list of every available model.

Supported provider values are `gemini`, `openai`, and `claude` (with `chatgpt`
as an OpenAI alias and `anthropic` as a Claude alias). Claude uses Anthropic's
Messages API. The bundled MQS and PEDro Claude entries use the model identifier
`claude-sonnet-4-20250514`; another Claude model can be passed and will use the
corresponding scale fallback prompt.

Prompt selection is independent of model availability. The resolver looks for
an exact registered model and then applies its fallback rules, ending with the
scale's `generic` prompt. MQS currently uses one provider-neutral prompt rather
than separate prompts for Gemini model variants.

Generation and resilience options can be passed to `run_article()` and
`run_dataset()`:

```r
result <- run_article(
  article_path = "path/to/article.pdf",
  temperature = 0,
  top_p = 0.1,
  timeout = 300,
  max_retries = 3,
  retry_wait_seconds = 1,
  retry_backoff = 2,
  rate_limit_seconds = 0
)
```

For reproducible scoring, use a low temperature and record the prompt,
provider, model, and runtime settings in the audit output.

To inspect the models currently exposed by a provider, independently of any
scale, use:

```r
available_provider_models("gemini")
available_provider_models("openai")
available_provider_models("claude")
```

This function queries each provider's models endpoint and therefore requires
the corresponding API key. It is intentionally not hard-coded, because the
available model catalogue changes over time.

## Scales and prompt registry

Registered scales live under `inst/scales`:

```text
inst/scales/<scale>/<prompt_variant>/
  prompt.md
  metadata.json
```

The prompt contains the operational instructions for the LLM. `metadata.json`
declares the formal item definition, allowed decisions, total-score rules, and
the response schema. These two files must agree.

The response schema is fail-closed: malformed JSON, missing items, unexpected
decisions, or missing required fields are rejected rather than silently scored.
Each item result contains a decision, evidence, and reason.

To inspect the registry:

```r
available_scales()
resolved <- resolve_prompt("mqs", "gemini-3.6-flash")
resolved$prompt_path

audit <- audit_model_registry(output_dir = "results/registry_audit")
audit$checks
```

To add a scale, see [ADD_NEW_SCALE_SKILL.md](ADD_NEW_SCALE_SKILL.md).

## Validation modes

Free mode evaluates a document without reference scores:

```r
result <- run_article("path/to/article.pdf", validation_mode = "free")
```

Reference mode compares the model's item decisions with previously reviewed
scores while preserving the raw response:

```r
reference <- c(Item_1 = 1, Item_2 = 0.5, Item_3 = 1, Item_4 = 1,
               Item_5 = 1, Item_6 = 0, Item_7 = 1, Item_8 = 0.5,
               Item_9 = 1, Item_10 = 1)

result <- run_article(
  "path/to/article.pdf",
  validation_mode = "reference",
  reference_scores = reference
)

result$validation
```

For datasets, use `reference_csv` with an `ID` column and `Item_1` through
`Item_n` columns.

## Outputs and reproducibility

Audit outputs record the requested and selected prompt, provider, model,
generation settings, input sizes, and SHA-256 hashes for the extracted text,
prompt, request, and raw response. This makes it possible to identify changes
in source documents, prompts, or runtime configuration.

## Tests and package development

Run the test suite from the package directory:

```powershell
Rscript -e "testthat::test_dir('tests/testthat')"
```

Build the source package with:

```powershell
R CMD build .
```

Do not commit `.Renviron` or files containing real API keys.
